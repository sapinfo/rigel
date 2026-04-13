# ─── Rigel SvelteKit Production Build ───
# Multi-stage: build → slim runtime

FROM node:22-alpine AS builder
WORKDIR /app

# SvelteKit $env/static/public requires build-time env vars
# These are baked into the client bundle at build time
ARG PUBLIC_SUPABASE_URL=http://localhost:8000
ARG PUBLIC_SUPABASE_ANON_KEY=placeholder
ENV PUBLIC_SUPABASE_URL=$PUBLIC_SUPABASE_URL
ENV PUBLIC_SUPABASE_ANON_KEY=$PUBLIC_SUPABASE_ANON_KEY

COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/build ./build
COPY --from=builder /app/package*.json ./
# --ignore-scripts: skip "prepare" (svelte-kit sync) which needs devDependencies
RUN npm ci --omit=dev --ignore-scripts
EXPOSE 3000
CMD ["node", "build/index.js"]
