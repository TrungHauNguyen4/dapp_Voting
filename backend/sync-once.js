import { syncOnce } from "./sync.js";

async function run() {
  try {
    const result = await syncOnce();
    console.log("Dong bo thanh cong:", result);
    process.exit(0);
  } catch (error) {
    console.error("Dong bo that bai:", error?.message || error);
    if (error?.stack) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

run();
