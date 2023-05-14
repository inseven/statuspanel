import { Footer } from "./Footer";
import { Stats } from "./Stats";

export function App() {
  return (
    <div className="h-screen bg-gray-100 px-8">
      <h1>StatusPanel Service</h1>

      <Stats />

      <Footer />
    </div>
  );
}
