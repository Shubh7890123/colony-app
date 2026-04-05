import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface NotificationRequest {
  target_user_id: string
  title: string
  body: string
  data?: Record<string, any>
}

serve(async (req) => {
  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get request body
    const { target_user_id, title, body, data }: NotificationRequest = await req.json()

    if (!target_user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client with service role key
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get FCM token for target user
    const { data: tokenData, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('fcm_token')
      .eq('user_id', target_user_id)
      .single()

    if (tokenError || !tokenData?.fcm_token) {
      console.log('No FCM token found for user:', target_user_id)
      return new Response(
        JSON.stringify({ message: 'User has no FCM token registered' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    const fcmToken = tokenData.fcm_token

    // Get sender's profile for notification
    const senderId = data?.sender_id
    let senderProfile = null
    if (senderId) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .eq('id', senderId)
        .single()
      senderProfile = profile
    }

    // Prepare notification payload
    const notificationPayload = {
      to: fcmToken,
      notification: {
        title: title,
        body: body,
        // Use sender's avatar as image if available
        image: senderProfile?.avatar_url || undefined,
      },
      data: {
        ...data,
        sender_name: senderProfile?.display_name || senderProfile?.username || 'User',
        sender_avatar: senderProfile?.avatar_url || '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        notification: {
          channel_id: data?.type === 'wave' ? 'waves_channel' : 
                      data?.type === 'message' ? 'messages_channel' : 
                      data?.type === 'call' ? 'calls_channel' : 'general_channel',
          priority: 'high',
          default_sound: true,
          default_vibrate_timings: true,
          default_light_settings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    }

    // Send via FCM API
    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${Deno.env.get('FCM_SERVER_KEY')}`,
      },
      body: JSON.stringify(notificationPayload),
    })

    const fcmResult = await fcmResponse.json()

    if (!fcmResponse.ok) {
      console.error('FCM error:', fcmResult)
      return new Response(
        JSON.stringify({ error: 'Failed to send notification', details: fcmResult }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log('Notification sent successfully:', fcmResult)

    return new Response(
      JSON.stringify({ success: true, messageId: fcmResult.message_id }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error sending notification:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
