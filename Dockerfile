FROM node:22-bookworm-slim AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN corepack enable

FROM base AS dependencies
WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
RUN pnpm install --frozen-lockfile

FROM base AS builder
WORKDIR /app
ENV NEXT_OUTPUT_MODE=standalone

COPY --from=dependencies /app/node_modules ./node_modules
COPY . .

ARG NEXT_PUBLIC_GITHUB_OWNER=feiyuu-chen
ARG NEXT_PUBLIC_GITHUB_REPO=2025-blog-public
ARG NEXT_PUBLIC_GITHUB_BRANCH=main
ARG NEXT_PUBLIC_GITHUB_APP_ID=-

ENV NEXT_PUBLIC_GITHUB_OWNER=$NEXT_PUBLIC_GITHUB_OWNER
ENV NEXT_PUBLIC_GITHUB_REPO=$NEXT_PUBLIC_GITHUB_REPO
ENV NEXT_PUBLIC_GITHUB_BRANCH=$NEXT_PUBLIC_GITHUB_BRANCH
ENV NEXT_PUBLIC_GITHUB_APP_ID=$NEXT_PUBLIC_GITHUB_APP_ID

RUN pnpm build

FROM node:22-bookworm-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN groupadd --system --gid 1001 nodejs \
	&& useradd --system --uid 1001 --gid nodejs nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

CMD ["node", "server.js"]
