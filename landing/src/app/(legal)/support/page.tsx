import type { Metadata } from "next";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { getDictionary } from "@/i18n/dictionaries";

export const metadata: Metadata = {
  title: "Support — Lorescape",
  description:
    "Contact Lorescape support or browse frequently asked questions about the AI audio guide.",
  alternates: { canonical: "/support" },
};

export default function SupportPage() {
  const d = getDictionary("en");
  return (
    <>
      <Navbar d={d} homeHref="/en" />
      <main className="bg-paper pt-32 pb-24 px-6">
        <article
          className="
            max-w-3xl mx-auto text-ink-2 leading-relaxed
            [&_h2]:text-2xl [&_h2]:font-serif [&_h2]:font-bold [&_h2]:text-ink [&_h2]:tracking-wide [&_h2]:mb-4
            [&_p]:mb-4
            [&_strong]:text-ink [&_strong]:font-semibold
            [&_a]:text-clay [&_a]:underline [&_a]:underline-offset-2 hover:[&_a]:text-clay-deep
          "
        >
          <header className="mb-10">
            <h1 className="text-4xl md:text-5xl font-serif font-bold tracking-wide text-ink mb-3">
              👋 Welcome to Lorescape Support
            </h1>
          </header>

          <p>
            Thank you for choosing <strong>Lorescape</strong>. We are dedicated
            to providing you with the most immersive AI audio guide experience.
            If you have any questions, feedback, or need to report a bug,
            please feel free to reach out to us.
          </p>

          {/* Contact callout */}
          <div className="paper-card rounded-2xl p-6 my-8 border-l-4 border-clay/60">
            <div className="flex items-start gap-3">
              <span className="text-2xl leading-none" aria-hidden="true">
                📧
              </span>
              <div className="flex-1 min-w-0">
                <h2>Contact Us</h2>
                <ul className="space-y-2 list-disc ml-6">
                  <li>
                    <strong>Support Email</strong>:{" "}
                    <a href="mailto:support@lorescape.app">
                      support@lorescape.app
                    </a>
                  </li>
                  <li>
                    <strong>Response Time</strong>: We typically respond within
                    24–48 hours.
                  </li>
                </ul>
              </div>
            </div>
          </div>

          {/* FAQ callout */}
          <div className="paper-card rounded-2xl p-6 my-8 border-l-4 border-clay-deep/60">
            <div className="flex items-start gap-3">
              <span className="text-2xl leading-none" aria-hidden="true">
                ❓
              </span>
              <div className="flex-1 min-w-0">
                <h2>Frequently Asked Questions</h2>

                <p>
                  <strong>Q: Why can&apos;t I hear the audio guide?</strong>
                </p>
                <p>
                  A: Please check if your device is in silent mode and ensure
                  you have granted audio permissions to the app. We recommend
                  using headphones for the best immersive experience.
                </p>

                <p>
                  <strong>Q: Is an internet connection required?</strong>
                </p>
                <p>
                  A: Yes. An active internet connection is required to
                  generate real-time historical insights based on your
                  location.
                </p>

                <p>
                  <strong>Q: Is my location being tracked?</strong>
                </p>
                <p>
                  A: <strong>Lorescape</strong> only accesses your location
                  when you use the &quot;Explore&quot; feature to find nearby
                  points of interest. We do not track your location in the
                  background. Your privacy is our priority.
                </p>

                <p>
                  <strong>
                    Q: Is the historical information provided by AI 100%
                    accurate?
                  </strong>
                </p>
                <p>
                  A: Our AI persona acts as a &quot;Rigorous Historian&quot;
                  and strives to provide fact-based information. However,
                  AI-generated content may occasionally contain errors. If you
                  spot any inaccuracies, please let us know.
                </p>

                <p>
                  <strong>Q: How do I delete my account and data?</strong>
                </p>
                <p>
                  A: You can request account deletion at any time. Go to{" "}
                  <strong>[Settings]</strong> &gt;{" "}
                  <strong>[Delete Account]</strong> within the app. All your
                  personal data and &quot;Knowledge Journey&quot; records
                  will be permanently deleted immediately. You can also
                  contact us via email for assistance.
                </p>
              </div>
            </div>
          </div>
        </article>
      </main>
      <Footer d={d} homeHref="/en" />
    </>
  );
}
