// @ts-nocheck
/// <reference lib="deno.ns" />
/// <reference lib="dom" />

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

function base64UrlEncode(input: string): string {
  return btoa(input).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const normalized = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\n/g, '')
    .replace(/\r/g, '')
    .trim()

  const binary = Uint8Array.from(atob(normalized), (c) => c.charCodeAt(0))
  return await crypto.subtle.importKey(
    'pkcs8',
    binary.buffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  )
}

async function getGoogleAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')
  const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID')

  if (!clientEmail || !privateKey || !projectId) {
    throw new Error('Missing FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY')
  }

  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const encodedHeader = base64UrlEncode(JSON.stringify(header))
  const encodedPayload = base64UrlEncode(JSON.stringify(payload))
  const unsignedJwt = `${encodedHeader}.${encodedPayload}`
  const key = await importPrivateKey(privateKey.replace(/\\n/g, '\n'))
  const signatureBuffer = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(unsignedJwt),
  )
  const signatureBinary = String.fromCharCode(...new Uint8Array(signatureBuffer))
  const encodedSignature = base64UrlEncode(signatureBinary)
  const assertion = `${unsignedJwt}.${encodedSignature}`

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })

  const tokenJson = await tokenRes.json()
  if (!tokenRes.ok || !tokenJson.access_token) {
    throw new Error(`Google OAuth token error: ${JSON.stringify(tokenJson)}`)
  }
  return tokenJson.access_token as string
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

    // Get all active FCM tokens for target user (multi-device support)
    const { data: tokenRows, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('id, fcm_token')
      .eq('user_id', target_user_id)
      .not('fcm_token', 'is', null)

    if (tokenError || !tokenRows || tokenRows.length === 0) {
      console.log('No FCM token found for user:', target_user_id)
      return new Response(
        JSON.stringify({ message: 'User has no FCM token registered' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get sender's profile for notification
    const senderId = data?.sender_id
    let senderProfile: Record<string, unknown> | null = null
    if (senderId) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .eq('id', senderId)
        .single()
      senderProfile = profile
    }

    const invalidTokenIds: string[] = []
    const results: Array<Record<string, unknown>> = []
    const accessToken = await getGoogleAccessToken()
    const firebaseProjectId = Deno.env.get('FIREBASE_PROJECT_ID')
    if (!firebaseProjectId) {
      return new Response(
        JSON.stringify({ error: 'FIREBASE_PROJECT_ID is not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    for (const row of tokenRows) {
      const notificationPayload = {
        message: {
          token: row.fcm_token,
          notification: {
            title,
            body,
            image: (senderProfile?.avatar_url as string | undefined) || undefined,
          },
          data: {
            ...Object.fromEntries(
              Object.entries({
                ...data,
                sender_name:
                  (senderProfile?.display_name as string | undefined) ||
                  (senderProfile?.username as string | undefined) ||
                  'User',
                sender_avatar: (senderProfile?.avatar_url as string | undefined) || '',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
              }).map(([k, v]) => [k, String(v ?? '')]),
            ),
          },
          android: {
            priority: 'high',
            notification: {
              channel_id: data?.type === 'wave' ? 'waves_channel' :
                          data?.type === 'message' ? 'messages_channel' :
                          data?.type === 'call' ? 'calls_channel' : 'general_channel',
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
        },
      }

      const fcmResponse = await fetch(
        `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
        {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify(notificationPayload),
      })

      const fcmResult = await fcmResponse.json()
      results.push({
        token_id: row.id,
        ok: fcmResponse.ok,
        result: fcmResult,
      })

      const errorCode = fcmResult?.error?.status as string | undefined
      const errorMsg = (fcmResult?.error?.message ?? '').toString()
      if (
        errorCode === 'NOT_FOUND' ||
        errorCode === 'UNREGISTERED' ||
        errorMsg.includes('registration token is not a valid FCM registration token') ||
        errorMsg.includes('Requested entity was not found')
      ) {
        invalidTokenIds.push(row.id)
      }
    }

    if (invalidTokenIds.length > 0) {
      await supabase.from('user_fcm_tokens').delete().in('id', invalidTokenIds)
    }

    return new Response(
      JSON.stringify({
        success: true,
        total_tokens: tokenRows.length,
        invalid_tokens_removed: invalidTokenIds.length,
        results,
      }),
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
