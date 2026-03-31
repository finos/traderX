import { Injectable } from '@angular/core';
import { environment } from 'main/environments/environment';

type SubscriptionRecord = {
    sid: number;
    topic: string;
    callback: (...args: any[]) => void;
};

type PendingMsg = {
    subject: string;
    sid: number;
    bytes: number;
};

@Injectable({
    providedIn: 'root'
})
export class TradeFeedService {
    private socket: WebSocket | null = null;
    private reconnectTimer: number | null = null;
    private connected = false;
    private nextSid = 1;
    private pendingData = '';
    private pendingMsg: PendingMsg | null = null;
    private readonly subscriptions = new Map<number, SubscriptionRecord>();

    constructor() {
        this.connect();
    }

    private connect() {
        if (this.socket && (this.socket.readyState === WebSocket.OPEN || this.socket.readyState === WebSocket.CONNECTING)) {
            return;
        }
        const ws = new WebSocket(environment.tradeFeedUrl);
        this.socket = ws;

        ws.onopen = () => {
            this.connected = true;
            this.pendingData = '';
            this.pendingMsg = null;
            this.sendRaw('CONNECT {"protocol":1,"verbose":false,"pedantic":false,"echo":false}\r\n');
            this.sendRaw('PING\r\n');
            this.resubscribeAll();
            console.log(`Trade feed (NATS websocket) connected: ${environment.tradeFeedUrl}`);
        };

        ws.onmessage = (event) => {
            void this.handleIncoming(event.data);
        };

        ws.onerror = (event) => {
            console.error('NATS websocket error', event);
        };

        ws.onclose = () => {
            this.connected = false;
            this.pendingData = '';
            this.pendingMsg = null;
            this.scheduleReconnect();
            console.warn('NATS websocket disconnected; reconnect scheduled');
        };
    }

    private scheduleReconnect() {
        if (this.reconnectTimer !== null) {
            window.clearTimeout(this.reconnectTimer);
        }
        this.reconnectTimer = window.setTimeout(() => {
            this.reconnectTimer = null;
            this.connect();
        }, 1000);
    }

    private sendRaw(payload: string) {
        if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
            return;
        }
        this.socket.send(payload);
    }

    private resubscribeAll() {
        for (const subscription of this.subscriptions.values()) {
            this.sendRaw(`SUB ${subscription.topic} ${subscription.sid}\r\n`);
        }
        if (this.subscriptions.size > 0) {
            this.sendRaw('PING\r\n');
        }
    }

    private async handleIncoming(rawData: unknown) {
        if (typeof rawData === 'string') {
            this.consumeText(rawData);
            return;
        }
        if (rawData instanceof Blob) {
            const text = await rawData.text();
            this.consumeText(text);
            return;
        }
        if (rawData instanceof ArrayBuffer) {
            const text = new TextDecoder().decode(new Uint8Array(rawData));
            this.consumeText(text);
        }
    }

    private consumeText(chunk: string) {
        this.pendingData += chunk;

        while (true) {
            if (this.pendingMsg) {
                const total = this.pendingMsg.bytes + 2;
                if (this.pendingData.length < total) {
                    return;
                }

                const payload = this.pendingData.slice(0, this.pendingMsg.bytes);
                this.pendingData = this.pendingData.slice(total);
                this.dispatchMessage(this.pendingMsg.sid, payload);
                this.pendingMsg = null;
                continue;
            }

            const lineEnd = this.pendingData.indexOf('\r\n');
            if (lineEnd < 0) {
                return;
            }

            const line = this.pendingData.slice(0, lineEnd);
            this.pendingData = this.pendingData.slice(lineEnd + 2);
            if (!line) {
                continue;
            }

            if (line.startsWith('PING')) {
                this.sendRaw('PONG\r\n');
                continue;
            }

            if (line.startsWith('INFO') || line.startsWith('PONG')) {
                continue;
            }

            if (line.startsWith('MSG ')) {
                const parts = line.split(' ');
                if (parts.length < 4) {
                    continue;
                }
                const subject = parts[1];
                const sid = Number(parts[2]);
                const bytes = Number(parts[parts.length - 1]);
                if (!Number.isFinite(sid) || !Number.isFinite(bytes)) {
                    continue;
                }
                this.pendingMsg = { subject, sid, bytes };
            }
        }
    }

    private dispatchMessage(sid: number, payloadText: string) {
        const record = this.subscriptions.get(sid);
        if (!record) {
            return;
        }
        try {
            const parsed = JSON.parse(payloadText);
            if (parsed && typeof parsed === 'object' && 'payload' in parsed) {
                record.callback((parsed as any).payload);
            } else {
                record.callback(parsed);
            }
        } catch (err) {
            console.error('Failed to parse NATS websocket payload', err);
        }
    }

    private removeSubscription(sid: number) {
        this.subscriptions.delete(sid);
        this.sendRaw(`UNSUB ${sid}\r\n`);
    }

    public subscribe(topic: string, callback: (...args: any[]) => void) {
        const sid = this.nextSid++;
        this.subscriptions.set(sid, { sid, topic, callback });
        this.connect();
        this.sendRaw(`SUB ${topic} ${sid}\r\n`);
        this.sendRaw('PING\r\n');
        console.log(`Subscribed to NATS topic ${topic} (sid=${sid})`);

        return () => {
            this.removeSubscription(sid);
        };
    }

    public unSubscribe(topic: string, callback: (...args: any[]) => void) {
        for (const [sid, record] of this.subscriptions.entries()) {
            if (record.topic === topic && record.callback === callback) {
                this.removeSubscription(sid);
            }
        }
    }
}
