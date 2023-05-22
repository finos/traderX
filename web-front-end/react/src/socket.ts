// import { Server } from 'socket.io';
import { io } from 'socket.io-client';

// "undefined" means the URL will be computed from the `window.location` object
const URL = process.env.NODE_ENV === 'production' ? undefined : 'http://localhost:18086';

//@ts-ignore
export const socket = io(URL);

// const io = new Server({
//   cors: {
//     origin: "http://localhost:3000"
//   }
// });

// io.listen(3000);