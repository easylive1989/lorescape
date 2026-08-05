import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import VideoDemo from "@/components/VideoDemo";
import Manifesto from "@/components/Manifesto";
import LocalStories from "@/components/LocalStories";
import ManyAngles from "@/components/ManyAngles";
import ExploreNearby from "@/components/ExploreNearby";
import JourneyJournal from "@/components/JourneyJournal";
import Trust from "@/components/Trust";
import FinalCTA from "@/components/FinalCTA";
import Footer from "@/components/Footer";
import { getDictionary } from "@/i18n/dictionaries";
import { isLocale } from "@/i18n/config";
import { notFound } from "next/navigation";

export default function Home({ params }: { params: { locale: string } }) {
  if (!isLocale(params.locale)) notFound();
  const d = getDictionary(params.locale);
  return (
    <>
      <Navbar d={d} homeHref="" />
      <main>
        <Hero d={d.hero} store={d.storeButtons} />
        <VideoDemo d={d.videoDemo} />
        <Manifesto d={d.manifesto} />
        <LocalStories d={d.localStories} />
        <ManyAngles d={d.manyAngles} />
        <ExploreNearby d={d.exploreNearby} />
        <JourneyJournal d={d.journeyJournal} />
        <Trust d={d.trust} />
        <FinalCTA d={d.finalCTA} store={d.storeButtons} />
      </main>
      <Footer d={d} homeHref="" />
    </>
  );
}
