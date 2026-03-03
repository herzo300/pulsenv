// supabase/functions/api/index.ts
// Edge Function for handling complaints API

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const jsonResponse = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status,
  })

function resolvePath(url: URL): string {
  const marker = '/functions/v1/api/'
  const idx = url.pathname.indexOf(marker)
  if (idx >= 0) {
    return url.pathname.slice(idx + marker.length).replace(/^\/+/, '')
  }
  return url.pathname.replace(/^\/+/, '').replace(/^api\/+/, '')
}

async function sendEmail(body: Record<string, unknown>) {
  const resendApiKey = Deno.env.get('RESEND_API_KEY') ?? ''
  if (!resendApiKey) {
    return jsonResponse({ ok: false, error: 'RESEND_API_KEY is not configured' }, 500)
  }

  const toEmail = String(body.to_email ?? '').trim()
  const toName = String(body.to_name ?? '').trim()
  const subject = String(body.subject ?? '').trim()
  const htmlBody = String(body.body ?? '').trim()
  const fromName = String(body.from_name ?? 'Пульс города').trim()
  const fromEmail = Deno.env.get('RESEND_FROM_EMAIL') ?? 'onboarding@resend.dev'

  if (!toEmail || !subject || !htmlBody) {
    return jsonResponse({ ok: false, error: 'to_email, subject and body are required' }, 400)
  }

  const toField = toName ? `${toName} <${toEmail}>` : toEmail
  const resendResp = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: `${fromName} <${fromEmail}>`,
      to: [toField],
      subject,
      html: htmlBody,
    }),
  })

  const resendData = await resendResp.json().catch(() => ({}))
  if (!resendResp.ok) {
    return jsonResponse({ ok: false, error: resendData }, 502)
  }
  return jsonResponse({ ok: true, provider: 'resend', result: resendData }, 200)
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const url = new URL(req.url)
    const path = resolvePath(url)
    const normalizedPath = path.replace(/^api\//, '')

    // GET /health
    if (req.method === 'GET' && normalizedPath === 'health') {
      return jsonResponse({
        status: 'ok',
        service: 'supabase-functions-api',
        endpoints: ['/health', '/send-email', '/api/join', '/complaints', '/stats', '/infographic'],
      })
    }

    // POST /send-email
    if (req.method === 'POST' && normalizedPath === 'send-email') {
      const body = await req.json().catch(() => ({}))
      return await sendEmail(body as Record<string, unknown>)
    }

    // POST /api/join
    if (req.method === 'POST' && normalizedPath === 'join') {
      const body = await req.json().catch(() => ({}))
      const complaintId = String((body as Record<string, unknown>).complaint_id ?? '').trim()
      if (!complaintId) {
        return jsonResponse({ ok: false, error: 'complaint_id is required' }, 400)
      }
      const numericId = Number.parseInt(complaintId, 10)
      if (!Number.isFinite(numericId)) {
        return jsonResponse({ ok: false, error: 'complaint_id must be numeric' }, 400)
      }

      const { data: existing, error: fetchErr } = await supabaseClient
        .from('complaints')
        .select('id,supporters')
        .eq('id', numericId)
        .single()
      if (fetchErr || !existing) {
        return jsonResponse({ ok: false, error: 'complaint not found' }, 404)
      }

      const supporters = Number(existing.supporters ?? 0) + 1
      const { data: updated, error: updateErr } = await supabaseClient
        .from('complaints')
        .update({ supporters })
        .eq('id', numericId)
        .select('id,supporters')
        .single()

      if (updateErr || !updated) {
        return jsonResponse({ ok: false, error: updateErr?.message ?? 'update failed' }, 500)
      }
      return jsonResponse({ ok: true, complaint_id: updated.id, supporters: updated.supporters }, 200)
    }

    
    // POST /api/collective-email
    if (req.method === 'POST' && normalizedPath === 'collective-email') {
      const body = await req.json().catch(() => ({}))
      const complaintId = String(body.complaint_id ?? '').trim()
      
      if (!complaintId) {
        return jsonResponse({ ok: false, error: 'complaint_id is required' }, 400)
      }
      
      const { data: complaint } = await supabaseClient
        .from('complaints')
        .select('*')
        .eq('id', complaintId)
        .single()
        
      if (!complaint) {
        return jsonResponse({ ok: false, error: 'complaint not found' }, 404)
      }
      
      // Compose email
      const emailBody = {
        to_email: 'admin@nizhnevartovsk.ru', // Placeholder for administration email
        to_name: 'Администрация г. Нижневартовска',
        subject: `[КОЛЛЕКТИВНАЯ ЖАЛОБА] ${complaint.category}: ${complaint.address || 'Не указан'}`,
        body: `
          <h2>Коллективное обращение граждан</h2>
          <p><strong>Категория:</strong> ${complaint.category}</p>
          <p><strong>Адрес:</strong> ${complaint.address || 'Не указан'}</p>
          <p><strong>Описание проблемы:</strong><br/>${complaint.description || complaint.summary || 'Без описания'}</p>
          <p>Данную проблему поддержали <strong>${complaint.supporters || 10}</strong> человек.</p>
          <p>Просим принять меры по устранению нарушения.</p>
        `
      }
      
      // Call sendEmail internally
      return await sendEmail(emailBody)
    }

    // GET /api/complaints - List complaints
    if (req.method === 'GET' && normalizedPath === 'complaints') {
      const { data, error } = await supabaseClient
        .from('complaints')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100)

      if (error) throw error

      return jsonResponse(data, 200)
    }

    // GET /api/complaints/:id - Get single complaint
    if (req.method === 'GET' && normalizedPath.startsWith('complaints/')) {
      const id = normalizedPath.split('/')[1]
      const { data, error } = await supabaseClient
        .from('complaints')
        .select('*')
        .eq('id', id)
        .single()

      if (error) throw error

      return jsonResponse(data, 200)
    }

    // POST /api/complaints - Create complaint
    if (req.method === 'POST' && normalizedPath === 'complaints') {
      const body = await req.json()
      
      const { data, error } = await supabaseClient
        .from('complaints')
        .insert([{
          category: body.category,
          description: body.description,
          address: body.address,
          lat: body.lat,
          lng: body.lng,
          status: body.status || 'open',
          source: body.source || 'webapp',
          user_id: body.user_id,
        }])
        .select()

      if (error) throw error

      return jsonResponse(data, 201)
    }

    // PUT /api/complaints/:id - Update complaint
    if (req.method === 'PUT' && normalizedPath.startsWith('complaints/')) {
      const id = normalizedPath.split('/')[1]
      const body = await req.json()
      
      const { data, error } = await supabaseClient
        .from('complaints')
        .update(body)
        .eq('id', id)
        .select()

      if (error) throw error

      return jsonResponse(data, 200)
    }

    // GET /api/stats - Get statistics
    if (req.method === 'GET' && normalizedPath === 'stats') {
      const { data, error } = await supabaseClient
        .from('complaint_stats')
        .select('*')
        .single()

      if (error) throw error

      return jsonResponse(data, 200)
    }

    // GET /api/infographic - Get infographic data
    if (req.method === 'GET' && normalizedPath === 'infographic') {
      const { data, error } = await supabaseClient
        .from('infographic_data')
        .select('*')

      if (error) throw error

      // Convert to object format like Firebase
      const result = {}
      data.forEach(item => {
        result[item.data_type] = item.data
      })

      return jsonResponse(result, 200)
    }

    // POST /webhook/telegram - Telegram Bot Webhook
    if (req.method === 'POST' && (normalizedPath === 'webhook/telegram' || normalizedPath === 'telegram-webhook')) {
      const update = await req.json().catch(() => ({}))
      
      // Forward update to Python backend or process here
      // For now, just acknowledge receipt
      const message = update.message || update.callback_query?.message
      if (message) {
        console.log(`Telegram update from ${message.from?.username || message.from?.id}: ${message.text || '[non-text]'}`)
      }
      
      // Return empty 200 to acknowledge
      return new Response('ok', { status: 200 })
    }

    return jsonResponse({ error: 'Not found' }, 404)

  } catch (error) {
    return jsonResponse({ error: error.message }, 400)
  }
})
