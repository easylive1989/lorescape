import type { Metadata } from "next";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { getDictionary } from "@/i18n/dictionaries";

export const metadata: Metadata = {
  title: "Image Credits — Lorescape",
  description:
    "Attribution for the photography used on the Lorescape landing page.",
  alternates: { canonical: "/credits" },
};

interface Credit {
  subject: string;
  author: string;
  license: string;
  licenseUrl: string;
  source: string;
  note?: string;
}

const credits: Credit[] = [
  {
    subject: "St. Peter's Basilica, Vatican",
    author: "Jebulon",
    license: "CC0",
    licenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/",
    source: "https://commons.wikimedia.org/w/index.php?curid=29562993",
    note: "Public domain — attribution not required, credited with thanks.",
  },
  {
    subject: "Agra Fort, India",
    author: "A.Savin",
    license: "Free Art License 1.3",
    licenseUrl: "https://artlibre.org/licence/lal/en/",
    source: "https://commons.wikimedia.org/w/index.php?curid=49028843",
  },
  {
    subject: "朝聖宮 Chaosheng Temple, Taichung",
    author: "Outlookxp",
    license: "CC BY-SA 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0/",
    source: "https://commons.wikimedia.org/w/index.php?curid=64882351",
  },
  {
    subject: "Forest path, Finland",
    author: "Sanzzu",
    license: "CC BY-SA 4.0",
    licenseUrl: "https://creativecommons.org/licenses/by-sa/4.0/",
    source: "https://commons.wikimedia.org/w/index.php?curid=191767832",
  },
];

export default function CreditsPage() {
  const d = getDictionary("en");
  return (
    <>
      <Navbar d={d} homeHref="/en" />
      <main className="bg-paper pt-32 pb-24 px-6">
        <article
          className="
            max-w-3xl mx-auto text-ink-2 leading-relaxed
            [&_a]:text-clay [&_a]:underline [&_a]:underline-offset-2 hover:[&_a]:text-clay-deep
            [&_strong]:text-ink [&_strong]:font-semibold
          "
        >
          <header className="mb-10">
            <h1 className="text-4xl md:text-5xl font-serif font-bold tracking-wide text-ink mb-3">
              圖片來源 · Image Credits
            </h1>
            <p className="text-sm uppercase tracking-widest text-ink-3">
              Photography on this site
            </p>
          </header>

          <p className="mb-8">
            本站使用的景點照片來自 Wikimedia Commons，依各自的授權條款使用並標示
            出處如下。The photography on this landing page is sourced from
            Wikimedia Commons and used under the licenses below.
          </p>

          <ul className="space-y-6">
            {credits.map((c) => (
              <li key={c.source} className="paper-card rounded-2xl p-5">
                <p className="mb-1">
                  <strong>{c.subject}</strong>
                </p>
                <p className="text-sm">
                  © {c.author} ·{" "}
                  <a href={c.licenseUrl} target="_blank" rel="noopener noreferrer">
                    {c.license}
                  </a>{" "}
                  ·{" "}
                  <a href={c.source} target="_blank" rel="noopener noreferrer">
                    Wikimedia Commons
                  </a>
                </p>
                {c.note && (
                  <p className="text-sm text-ink-3 mt-1">{c.note}</p>
                )}
              </li>
            ))}
          </ul>
        </article>
      </main>
      <Footer d={d} homeHref="/en" />
    </>
  );
}
