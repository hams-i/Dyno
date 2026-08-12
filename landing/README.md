# Dyno Island — Landing

Marketing site for [Dyno Island](https://github.com/hams-i/Dyno). The hero demo recreates the **live Dynamic Island UI** in React (not screenshots).

## Stack

- Next.js 16 + TypeScript + Tailwind CSS v4
- [Magic UI](https://magicui.design) (Shimmer button, Blur fade, Dot pattern)
- `next-themes` — Dark / Light / System
- EN + TR via client-side locale context

## Design

- Accent: `#D1FE25`
- Dark default: black background, white text
- Light: white background, black text

## Development

```sh
cd landing
pnpm install
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000).

## Production build

```sh
pnpm build
pnpm start
```
