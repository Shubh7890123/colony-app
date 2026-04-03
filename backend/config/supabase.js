const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Validate configuration
if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase configuration. Check your .env file.');
  console.error(`SUPABASE_URL: ${supabaseUrl ? 'Set' : 'Missing'}`);
  console.error(`SUPABASE_ANON_KEY: ${supabaseAnonKey ? 'Set' : 'Missing'}`);
  process.exit(1);
}

// Create Supabase clients
const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Service role client for admin operations (server-side only)
const supabaseAdmin = supabaseServiceRoleKey 
  ? createClient(supabaseUrl, supabaseServiceRoleKey)
  : null;

module.exports = {
  supabase,
  supabaseAdmin,
  supabaseUrl,
  supabaseAnonKey,
  supabaseServiceRoleKey
};