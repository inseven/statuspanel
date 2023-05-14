import { Footer } from "./Footer";
import { Stats } from "./Stats";

export function App() {
  return (
    <div className="p-8 m-auto max-w-3xl">
      <h1 className="text-3xl font-bold">StatusPanel Service</h1>

      <Stats />

      <Footer />
    </div>
  );
}
