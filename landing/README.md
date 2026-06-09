# REACH — landing page

A small, self-contained, SEO-friendly marketing site for REACH. It's the
intended target for the in-app share CTA (`kShareUrl`) and a way to rank for
searches like *"calm number puzzle"* / *"daily number game"* that the app
itself can't (the store is saturated for the word "reach").

Plain static files — no build step, no framework:

```
landing/
  index.html     # the page (inline CSS + SVG-free; one file = trivial to host)
  privacy.html   # DRAFT privacy policy (required by the stores for ads/IAP)
  robots.txt
  sitemap.xml
```

## Deploy (pick one, all free)

- **Netlify** (easiest): drag the `landing/` folder onto app.netlify.com, or
  connect the repo and set **base directory = `landing`**, publish dir = `.`.
- **Vercel**: import the repo, set the **root directory = `landing`**.
- **GitHub Pages**: Pages only serves the repo root or `/docs`, so either move
  these files to `/docs`, or push `landing/`'s contents to a `gh-pages` branch.
- **Cloudflare Pages**: connect repo, build output dir = `landing`.

## Before publishing (TODO)

1. **Domain:** find-and-replace `https://reachpuzzle.com` everywhere
   (`index.html`, `privacy.html`, `robots.txt`, `sitemap.xml`) with your real
   domain. (Domain not bought yet — a cheap `.com` is fine; the app's store
   name stays "REACH" regardless.)
2. **Social image:** add a 1200×630 `assets/og-image.png` (the in-app result
   card style works well) so shared links render a preview.
3. **Store links:** replace the two "Coming soon" buttons in `index.html` with
   the real App Store / Play Store URLs once published.
4. **Privacy policy:** review `privacy.html` (fill the date + contact email;
   confirm the data list). Then point the app's `kPrivacyPolicyUrl`
   (`lib/config/app_constants.dart`) at `.../privacy.html`.
5. **Wire the CTA back to the app:** once live, set `kShareUrl` in
   `lib/config/app_constants.dart` to this site's URL so every shared Daily
   result links here.

## SEO notes

- Title + meta description target the searchable phrases; structured data
  (`SoftwareApplication` JSON-LD) enables an app rich result.
- Keep the copy honest and specific; a real, fast, content-true page is what
  ranks and converts. Consider adding a short "how to play" GIF later.
