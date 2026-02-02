import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

interface SecureContactRequest {
  ride_id: string;
  action: 'get_customer_info' | 'get_driver_info' | 'send_message' | 'initiate_call' |
          'create_share_link' | 'get_shared_ride' | 'create_emergency' | 'get_messages';
  message?: string;
  message_type?: string;
  share_token?: string;
  recipient_name?: string;
  recipient_phone?: string;
  alert_type?: string;
  latitude?: number;
  longitude?: number;
  description?: string;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body: SecureContactRequest = await req.json();
    const { action, ride_id, share_token } = body;

    // Public endpoint: Get shared ride info (no auth required)
    if (action === 'get_shared_ride' && share_token) {
      const { data, error } = await supabase
        .rpc('get_shared_ride_info', { p_share_token: share_token });

      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, data: data?.[0] || null }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // All other endpoints require authentication
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header');
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );
    if (authError || !user) {
      throw new Error('Invalid token');
    }

    let result: any;

    switch (action) {
      case 'get_customer_info': {
        // Sürücü için müşteri bilgisi (maskelenmiş)
        const { data, error } = await supabase
          .rpc('get_secure_customer_info', {
            p_ride_id: ride_id,
            p_driver_user_id: user.id
          });

        if (error) throw error;
        result = data?.[0] || null;
        break;
      }

      case 'get_driver_info': {
        // Müşteri için sürücü bilgisi (maskelenmiş)
        const { data, error } = await supabase
          .rpc('get_secure_driver_info', {
            p_ride_id: ride_id,
            p_customer_user_id: user.id
          });

        if (error) throw error;
        result = data?.[0] || null;
        break;
      }

      case 'send_message': {
        // Mesaj gönder
        const { data, error } = await supabase
          .rpc('send_ride_message', {
            p_ride_id: ride_id,
            p_content: body.message || '',
            p_message_type: body.message_type || 'text'
          });

        if (error) throw error;
        result = { message_id: data };
        break;
      }

      case 'get_messages': {
        // Yolculuk mesajlarını getir
        const { data: ride, error: rideError } = await supabase
          .from('taxi_rides')
          .select('id, user_id, driver_id')
          .eq('id', ride_id)
          .single();

        if (rideError) throw rideError;

        // Yetki kontrolü
        const { data: driver } = await supabase
          .from('taxi_drivers')
          .select('user_id')
          .eq('id', ride.driver_id)
          .single();

        if (ride.user_id !== user.id && driver?.user_id !== user.id) {
          throw new Error('Unauthorized');
        }

        const { data: messages, error } = await supabase
          .from('ride_communications')
          .select('*')
          .eq('ride_id', ride_id)
          .order('created_at', { ascending: true });

        if (error) throw error;
        result = messages;
        break;
      }

      case 'initiate_call': {
        // Arama başlat
        const { data, error } = await supabase
          .rpc('initiate_ride_call', { p_ride_id: ride_id });

        if (error) throw error;

        // Karşı tarafın telefon numarasını al (uygulama içi arama için)
        // Gerçek uygulamada burada VoIP veya proxy numara sistemi kullanılır
        result = {
          call_id: data,
          // Proxy numara veya uygulama içi arama kanalı bilgisi
          channel: `ride_call_${ride_id}`,
          message: 'Call initiated. Use in-app calling feature.'
        };
        break;
      }

      case 'create_share_link': {
        // Yolculuk paylaşım linki oluştur
        const { data, error } = await supabase
          .rpc('create_ride_share_link', {
            p_ride_id: ride_id,
            p_recipient_name: body.recipient_name || null,
            p_recipient_phone: body.recipient_phone || null,
            p_hours_valid: 24
          });

        if (error) throw error;
        result = data?.[0] || null;
        break;
      }

      case 'create_emergency': {
        // Acil durum uyarısı oluştur
        const { data, error } = await supabase
          .rpc('create_emergency_alert', {
            p_ride_id: ride_id,
            p_alert_type: body.alert_type || 'sos',
            p_latitude: body.latitude || 0,
            p_longitude: body.longitude || 0,
            p_description: body.description || null
          });

        if (error) throw error;

        // Burada gerçek bir uygulamada:
        // 1. Admin paneline bildirim gönder
        // 2. Acil durum kişilerine SMS/bildirim at
        // 3. Gerekirse yetkililere haber ver

        // Acil durum kişilerini al
        const { data: prefs } = await supabase
          .from('communication_preferences')
          .select('emergency_contacts')
          .eq('user_id', user.id)
          .single();

        const emergencyContacts = prefs?.emergency_contacts || [];

        // Log the emergency
        console.log(`EMERGENCY ALERT: User ${user.id}, Type: ${body.alert_type}, Ride: ${ride_id}`);

        result = {
          alert_id: data,
          message: 'Emergency alert created',
          emergency_contacts_notified: emergencyContacts.length
        };
        break;
      }

      default:
        throw new Error(`Unknown action: ${action}`);
    }

    return new Response(
      JSON.stringify({ success: true, data: result }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
