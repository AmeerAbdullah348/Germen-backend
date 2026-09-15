# Germen-backend

Backend for the [German Learning App](https://github.com/AmeerAbdullah348/Germen-frontend) — a Supabase project (Postgres + Auth + Edge Functions).

## Structure

- `supabase/schema.sql` — database schema (`profiles`, `word_progress` tables with Row Level Security). Run once in the Supabase Dashboard's SQL Editor.
- `supabase/functions/chat/` — Edge Function that proxies chatbot messages to the Groq API. The Groq API key is never exposed to the client — it's stored as a Supabase secret (`GROQ_API_KEY`) and read server-side only.

## Deploying the Edge Function

```
npx supabase login
npx supabase link --project-ref <your-project-ref>
npx supabase functions deploy chat
```

Set the Groq key as a secret in the Supabase Dashboard under Edge Functions → Secrets (name: `GROQ_API_KEY`), or via the CLI:

```
npx supabase secrets set GROQ_API_KEY=your-key-here
```
