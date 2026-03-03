// Supabase Edge Function: Telegram Webhook Handler
// Пульс города Нижневартовск

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const TG_BOT_TOKEN = Deno.env.get("TG_BOT_TOKEN") || "";
const TELEGRAM_API = `https://api.telegram.org/bot${TG_BOT_TOKEN}`;

// WebApp URLs (Supabase hosted)
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://xpainxohbdoruakcijyq.supabase.co";
const MAP_URL = `${SUPABASE_URL}/storage/v1/object/public/static/map.html`;
const INFO_URL = `${SUPABASE_URL}/storage/v1/object/public/static/info.html`;
const APP_URL = `${SUPABASE_URL}/storage/v1/object/public/static/app.html`;

// Fallback to Workers URLs if storage not configured
const MAP_URL_FALLBACK = "https://pulsenv.workers.dev/map";
const INFO_URL_FALLBACK = "https://pulsenv.workers.dev/info";
const APP_URL_FALLBACK = "https://pulsenv.workers.dev/app";

interface TelegramMessage {
  chat: { id: number };
  from?: { first_name?: string };
  text?: string;
}

interface TelegramCallbackQuery {
  id: string;
  data?: string;
  message: TelegramMessage;
}

interface TelegramUpdate {
  update_id: number;
  message?: TelegramMessage;
  callback_query?: TelegramCallbackQuery;
}

async function sendTelegramMessage(
  chatId: number,
  text: string,
  options: Record<string, unknown> = {}
): Promise<Response> {
  const body = {
    chat_id: chatId,
    text: text,
    parse_mode: "Markdown",
    ...options,
  };

  return fetch(`${TELEGRAM_API}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

async function answerCallbackQuery(callbackId: string, text = ""): Promise<Response> {
  const body: Record<string, string> = { callback_query_id: callbackId };
  if (text) body.text = text;

  return fetch(`${TELEGRAM_API}/answerCallbackQuery`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function getMainMenu() {
  return {
    inline_keyboard: [
      [
        { text: "📊 Инфографика", callback_data: "info" },
        { text: "🗺️ Карта", callback_data: "map" },
      ],
      [
        { text: "📱 Открыть приложение", web_app: { url: APP_URL_FALLBACK } },
      ],
    ],
  };
}

async function handleMessage(message: TelegramMessage): Promise<void> {
  const chatId = message.chat.id;
  const text = message.text || "";
  const firstName = message.from?.first_name || "друг";

  if (text === "/start") {
    await sendTelegramMessage(
      chatId,
      `👋 Привет, ${firstName}!\n\n` +
        `Я бот *Пульс города Нижневартовск* — твой помощник по городским проблемам.\n\n` +
        `📍 Используйте меню ниже для навигации:`,
      { reply_markup: getMainMenu() }
    );
  } else if (text === "/help") {
    await sendTelegramMessage(
      chatId,
      `ℹ️ *Помощь по боту*\n\n` +
        `Доступные команды:\n` +
        `/start — главное меню\n` +
        `/map — карта проблем\n` +
        `/info — инфографика города\n` +
        `/help — эта справка\n\n` +
        `Также вы можете отправить фото или описание проблемы.`
    );
  } else if (text === "/map" || text === "🗺️ Карта") {
    await sendTelegramMessage(chatId, "🗺️ *Карта проблем Нижневартовска*", {
      reply_markup: {
        inline_keyboard: [
          [{ text: "🗺️ Открыть карту", web_app: { url: MAP_URL_FALLBACK } }],
        ],
      },
    });
  } else if (text === "/info" || text === "📊 Инфографика") {
    await sendTelegramMessage(chatId, "📊 *Инфографика города Нижневартовск*", {
      reply_markup: {
        inline_keyboard: [
          [{ text: "📊 Открыть инфографику", web_app: { url: INFO_URL_FALLBACK } }],
        ],
      },
    });
  } else if (text) {
    await sendTelegramMessage(
      chatId,
      `Спасибо за сообщение! Используйте /start для открытия меню.`
    );
  }
}

async function handleCallbackQuery(callbackQuery: TelegramCallbackQuery): Promise<void> {
  const callbackId = callbackQuery.id;
  const data = callbackQuery.data || "";
  const chatId = callbackQuery.message.chat.id;

  await answerCallbackQuery(callbackId);

  if (data === "map") {
    await sendTelegramMessage(chatId, "🗺️ *Карта проблем Нижневартовска*", {
      reply_markup: {
        inline_keyboard: [
          [{ text: "🗺️ Открыть карту", web_app: { url: MAP_URL_FALLBACK } }],
        ],
      },
    });
  } else if (data === "info") {
    await sendTelegramMessage(chatId, "📊 *Инфографика города Нижневартовск*", {
      reply_markup: {
        inline_keyboard: [
          [{ text: "📊 Открыть инфографику", web_app: { url: INFO_URL_FALLBACK } }],
        ],
      },
    });
  }
}

serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Only accept POST
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ ok: false, error: "Method not allowed" }),
      { status: 405, headers: corsHeaders }
    );
  }

  // Check bot token
  if (!TG_BOT_TOKEN) {
    console.error("TG_BOT_TOKEN not configured");
    return new Response(
      JSON.stringify({ ok: false, error: "Bot token not configured" }),
      { status: 200, headers: corsHeaders }
    );
  }

  try {
    const update: TelegramUpdate = await req.json();

    if (update.callback_query) {
      await handleCallbackQuery(update.callback_query);
    } else if (update.message) {
      await handleMessage(update.message);
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: corsHeaders,
    });
  } catch (error) {
    console.error("Telegram webhook error:", error);
    // Always return 200 to prevent Telegram retries
    return new Response(
      JSON.stringify({ ok: false, error: String(error) }),
      { status: 200, headers: corsHeaders }
    );
  }
});
