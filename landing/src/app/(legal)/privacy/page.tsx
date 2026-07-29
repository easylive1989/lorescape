import type { Metadata } from "next";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { getDictionary } from "@/i18n/dictionaries";

export const metadata: Metadata = {
  title: "Privacy Policy — Lorescape",
  description:
    "How Lorescape collects, uses, and protects your information when you use our AI audio guide.",
  alternates: { canonical: "/privacy" },
};

export default function PrivacyPage() {
  const d = getDictionary("en");
  return (
    <>
      <Navbar d={d} homeHref="/en" />
      <main className="bg-paper pt-32 pb-24 px-6">
        <article
          className="
            max-w-3xl mx-auto text-ink-2 leading-relaxed
            [&_h2]:text-2xl [&_h2]:md:text-3xl [&_h2]:font-serif [&_h2]:font-bold [&_h2]:text-ink
            [&_h2]:tracking-wide [&_h2]:mt-12 [&_h2]:mb-4
            [&_p]:mb-4
            [&_ul]:mb-4 [&_ul]:space-y-2
            [&_ul>li]:list-disc [&_ul>li]:ml-6
            [&_ul>li>ul]:mt-2 [&_ul>li>ul]:mb-0
            [&_strong]:text-ink [&_strong]:font-semibold
            [&_a]:text-clay [&_a]:underline [&_a]:underline-offset-2 hover:[&_a]:text-clay-deep
          "
        >
          <header className="mb-10">
            <h1 className="text-4xl md:text-5xl font-serif font-bold tracking-wide text-ink mb-3">
              Privacy Policy
            </h1>
            <p className="text-sm uppercase tracking-widest text-ink-3">
              Last Updated: 2026-04-23
            </p>
          </header>

          <p>
            <strong>Lorescape</strong> (&quot;the App&quot;) values your privacy.
            This Privacy Policy explains how we collect, use, disclose, and
            store your information.
          </p>

          <h2>1. Information We Collect</h2>
          <p>
            To provide location-based AI guide services, we may collect the
            following types of information:
          </p>
          <ul>
            <li>
              <strong>Location Data</strong>
              <ul>
                <li>
                  We request access to your precise location (GPS coordinates)
                  when you use the &quot;Explore&quot; or &quot;Guide&quot;
                  features.
                </li>
                <li>
                  <strong>Purpose</strong>: Strictly used to fetch nearby
                  historical landmarks and generate context-aware audio content
                  tailored to your location.
                </li>
                <li>
                  <strong>Storage</strong>: Location data is processed locally
                  or sent to the server for real-time queries only while the
                  App is in use. We <strong>do not</strong> store your
                  historical movement history on our servers, nor do we track
                  your location in the background.
                </li>
              </ul>
            </li>
            <li>
              <strong>Usage Data &amp; Journey of Exploration</strong>
              <ul>
                <li>
                  We record your interactions within the App, such as which
                  landmarks you have visited and the narration depth you
                  selected (Brief / Deep Dive).
                </li>
                <li>
                  <strong>Purpose</strong>: Used to build your personalized
                  &quot;Journey of Exploration,&quot; allowing you to review
                  your cultural journey.
                </li>
              </ul>
            </li>
            <li>
              <strong>Device Information</strong>
              <ul>
                <li>
                  We collect technical data related to your device, such as
                  device model, OS version, language settings, and unique
                  device identifiers (non-personally identifiable).
                </li>
                <li>
                  <strong>Purpose</strong>: Used to improve App stability, fix
                  bugs (Crash Logs), and optimize user experience.
                </li>
              </ul>
            </li>
          </ul>

          <h2>2. AI Technology &amp; Data Processing</h2>
          <p>
            The App utilizes advanced Artificial Intelligence technologies
            (e.g., OpenAI GPT or Google Gemini) to generate guide content.
          </p>
          <ul>
            <li>
              <strong>Data Transmission</strong>: When you start a guide,
              metadata related to the landmark (e.g., name, location tags) is
              sent to third-party AI service providers to generate the text.
            </li>
            <li>
              <strong>Privacy Protection</strong>: Data sent to AI services{" "}
              <strong>does not include</strong> your personally identifiable
              information (PII). We ensure that third-party providers do not
              use this data to train their models.
            </li>
          </ul>

          <h2>3. Third-Party Services &amp; Data Sharing</h2>
          <p>
            We do not share your personal data with third parties, except in
            the following cases:
          </p>
          <ul>
            <li>
              <strong>Service Providers</strong>: We use third-party cloud
              services (e.g., database hosting, AI APIs) to operate the App.
              These providers only access necessary data to perform specific
              tasks.
            </li>
            <li>
              <strong>Legal Requirements</strong>: We may disclose your
              information if required by law, legal process, litigation, or
              requests from public and governmental authorities.
            </li>
          </ul>

          <h2>4. Data Security &amp; Retention</h2>
          <ul>
            <li>
              We implement industry-standard security measures to protect your
              data.
            </li>
            <li>
              Your &quot;Journey of Exploration&quot; data is retained until
              you choose to delete your account.
            </li>
          </ul>

          <h2>5. Your Rights (Account Deletion)</h2>
          <p>
            You have the right to delete your account and all associated data
            at any time.
          </p>
          <ul>
            <li>
              <strong>How to delete</strong>: Go to{" "}
              <strong>[Settings]</strong> &gt; tap{" "}
              <strong>[Delete Account]</strong> within the App.
            </li>
            <li>
              Once confirmed, all your guide history and personal settings will
              be permanently removed from our servers and cannot be recovered.
            </li>
          </ul>

          <h2>6. Children&apos;s Privacy</h2>
          <p>
            The App is not intended for children under the age of 13, and we
            do not knowingly collect personal information from children.
          </p>

          <h2>7. Contact Us</h2>
          <p>
            If you have any questions regarding this Privacy Policy, please
            contact us at:
          </p>
          <ul>
            <li>
              <strong>Email</strong>:{" "}
              <a href="mailto:easylive1989@gmail.com">
                easylive1989@gmail.com
              </a>
            </li>
          </ul>
        </article>
      </main>
      <Footer d={d} homeHref="/en" />
    </>
  );
}
