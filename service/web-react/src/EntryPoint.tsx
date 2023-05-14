import { App } from "./App";
import { Providers } from "./Providers";

export function EntryPoint() {
  return (
    <Providers>
      <App />
    </Providers>
  );
}
