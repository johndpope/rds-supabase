// // Save as end-to-end-test.js
const { createClient } = require('@supabase/supabase-js');
const { Pool } = require('pg');

// Configuration
const SUPABASE_URL = 'ws://localhost:8000/realtime/v1';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

const DB_CONFIG = {
  host: 'BALBLA.ap-southeast-2.rds.amazonaws.com',
  port: 5432,
  database: 'postgres',
  user: 'blabla',
  password: 'blabla'  // from your logs
};

// const DB_CONFIG = {
//   host: '0.0.0.0',
//   port: 5432,
//   database: 'postgres',
//   user: 'postgres',
//   password: 'postgres'  // from your logs
// };

// Create Supabase client
const supabase = createClient(SUPABASE_URL, ANON_KEY);
console.log('Created Supabase client');

// Create database connection for direct inserts
const pool = new Pool(DB_CONFIG);

// Track received messages
let messagesReceived = 0;
let changeType = null;

// Function to run the full test
async function runTest() {
  try {
    console.log('Starting end-to-end Realtime test');
    
    // 1. Set up Realtime subscription
    console.log('Setting up Realtime subscription...');
    const channel = supabase
  .channel('public:realtime_test')
  .on(
    'postgres_changes',
    { event: '*', schema: 'public', table: 'realtime_test' },
    (payload) => {
      messagesReceived++;
      changeType = payload.eventType;
      console.log('Change received!', JSON.stringify(payload, null, 2));
    }
  )
  .subscribe((status) => {
    console.log('Subscription status:', status);
  });
    
    // 2. Wait for subscription to be established
    console.log('Waiting for subscription to be established...');
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 3. Insert data directly through database connection
    console.log('Connecting to database...');
    const client = await pool.connect();
    
    try {
      console.log('Inserting test data...');
      await client.query(
        `INSERT INTO public.realtime_test (name) VALUES ($1)`,
        [`Test entry at ${new Date().toISOString()}`]
      );
      console.log('Data inserted successfully');
      
      // 4. Wait for notification
      console.log('Waiting for Realtime notification...');
      await new Promise(resolve => setTimeout(resolve, 5000));
      
      // 5. Check if we received the notification
      if (messagesReceived > 0) {
        console.log(`✅ SUCCESS! Received ${messagesReceived} notifications. Last change type: ${changeType}`);
      } else {
        console.log('❌ No notifications received within the timeout period.');
      }
      
      // 6. Update the data
      console.log('Updating test data...');
      await client.query(
        `UPDATE public.realtime_test SET name = $1 WHERE id = (SELECT MAX(id) FROM public.realtime_test)`,
        [`Updated at ${new Date().toISOString()}`]
      );
      console.log('Data updated successfully');
      
      // 7. Wait for update notification
      console.log('Waiting for update notification...');
      await new Promise(resolve => setTimeout(resolve, 5000));
      
      // 8. Delete the test data
      console.log('Deleting test data...');
      await client.query(
        `DELETE FROM public.realtime_test WHERE id = (SELECT MAX(id) FROM public.realtime_test)`
      );
      console.log('Data deleted successfully');
      
      // 9. Final wait for delete notification
      console.log('Waiting for delete notification...');
      await new Promise(resolve => setTimeout(resolve, 5000));
      
      // 10. Final status report
      console.log(`Final status: Received ${messagesReceived} notifications in total.`);
      if (messagesReceived > 0) {
        console.log('✅ Realtime is working! You received notifications for database changes.');
      } else {
        console.log('❌ Realtime subscription was established but no notifications were received.');
        console.log('Possible issues:');
        console.log('- Publication might not include the realtime_test table');
        console.log('- Trigger functions might not be set up correctly');
        console.log('- RLS policies might be blocking access');
      }
    } finally {
      // Clean up
      client.release();
      channel.unsubscribe();
    }
  } catch (error) {
    console.error('Error in test:', error);
  } finally {
    // Close database pool
    await pool.end();
    console.log('Test completed');
  }
}


runTest();
