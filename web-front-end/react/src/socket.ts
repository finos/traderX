// import { Server } from 'socket.io';
import { io } from 'socket.io-client';
import { Environment } from './env';
// "undefined" means the URL will be computed from the `window.location` object
const URL = process.env.NODE_ENV === 'production' ? undefined : Environment.trade_feed_url;

//@ts-ignore
export const socket = io(URL);

// const io = new Server({
//   cors: {
//     origin: "http://localhost:3000"
//   }
// });

// io.listen(3000);
