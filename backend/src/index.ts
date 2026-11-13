import { createApp } from "./app";
import { assertAuthConfigured } from "./modules/common/auth";

assertAuthConfigured();
const app = createApp();
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
