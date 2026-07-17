import { Injectable } from '@angular/core';
import { BehaviorSubject, Subject } from 'rxjs';
import { getAgent } from '@finos/fdc3';
import { Fdc3TickerCompatibilityBridgeService } from './fdc3-ticker-compatibility-bridge.service';

type Fdc3Listener = {
    unsubscribe: () => void;
};

type Fdc3Context = {
    type?: string;
    id?: { [key: string]: unknown };
    name?: unknown;
    traderxAction?: unknown;
    traderxActionRequestId?: unknown;
};

type Fdc3ChannelLike = {
    id: string;
    broadcast?: (context: unknown) => Promise<void> | void;
    getCurrentContext?: (contextType?: string) => Promise<Fdc3Context | null> | Fdc3Context | null;
};

type Fdc3DesktopAgentLike = {
    broadcast?: (context: unknown) => Promise<void> | void;
    raiseIntent?: (intent: string, context?: unknown) => Promise<unknown> | unknown;
    addContextListener?: (contextType: string | null, handler: (context: Fdc3Context) => void) => Promise<Fdc3Listener> | Fdc3Listener;
    addIntentListener?: (intent: string, handler: (context: Fdc3Context) => void) => Promise<Fdc3Listener> | Fdc3Listener;
    addIntentListenerWithContext?: (intent: string, contextType: string | string[], handler: (context: Fdc3Context) => void) => Promise<Fdc3Listener> | Fdc3Listener;
    getCurrentChannel?: () => Promise<Fdc3ChannelLike | null> | Fdc3ChannelLike | null;
    getCurrentContext?: (contextType?: string) => Promise<Fdc3Context | null> | Fdc3Context | null;
    getUserChannels?: () => Promise<Fdc3ChannelLike[]> | Fdc3ChannelLike[];
    joinUserChannel?: (channelId: string) => Promise<void> | void;
    addEventListener?: (eventType: string | null, handler: () => void) => Promise<Fdc3Listener> | Fdc3Listener | void;
    removeEventListener?: (eventType: string, handler: () => void) => void;
};

export type Fdc3InboundAction =
    | 'context'
    | 'ViewOrders'
    | 'TraderX.CreateTradeTicket'
    | 'TraderX.CreateOrderTicket';

export interface Fdc3InboundEvent {
    action: Fdc3InboundAction;
    ticker: string;
}

export interface Fdc3AccountEvent {
    accountId: number;
    displayName?: string;
}

@Injectable({
    providedIn: 'root'
})
export class Fdc3InteropService {
    readonly inboundEvents$ = new Subject<Fdc3InboundEvent>();
    readonly accountEvents$ = new Subject<Fdc3AccountEvent>();
    readonly isAgentAvailable$ = new BehaviorSubject<boolean>(false);
    readonly statusMessage$ = new BehaviorSubject<string>('FDC3: connecting...');

    private agent?: Fdc3DesktopAgentLike;
    private listeners: Fdc3Listener[] = [];
    private lastPublishedTicker?: string;
    private initializePromise?: Promise<boolean>;
    private reconnectTimer?: ReturnType<typeof setTimeout>;
    private readonly reconnectDelayMs = 2500;
    private contextSyncInterval?: ReturnType<typeof setInterval>;
    private channelChangedHandler?: () => void;
    private lastContextSignature?: string;
    private lastAccountSignature?: string;
    private lastPublishedAccountId?: number;

    constructor(private tickerBridge: Fdc3TickerCompatibilityBridgeService) {}

    async initialize(): Promise<boolean> {
        if (this.isAgentAvailable$.value && this.agent) {
            return this.isAgentAvailable$.value;
        }
        if (this.initializePromise) {
            return this.initializePromise;
        }
        this.initializePromise = this.initializeInternal().finally(() => {
            this.initializePromise = undefined;
        });
        return this.initializePromise;
    }

    async publishTickerSelection(traderxTicker: string): Promise<boolean> {
        if (!this.agent?.broadcast) {
            await this.initialize();
        }
        if (!this.agent?.broadcast) {
            return false;
        }
        const context = this.tickerBridge.toInstrumentContext(traderxTicker);
        if (!context?.id?.ticker) {
            return false;
        }
        if (context.id.ticker === this.lastPublishedTicker) {
            return true;
        }
        const currentChannel = await this.ensureUserChannel(this.agent);
        if (currentChannel?.broadcast) {
            await Promise.resolve(currentChannel.broadcast(context));
        } else {
            await Promise.resolve(this.agent.broadcast(context));
        }
        this.lastPublishedTicker = context.id.ticker;
        console.info('[fdc3] broadcasted instrument context', {
            context,
            channelId: currentChannel?.id ?? null
        });
        this.statusMessage$.next(`FDC3 outbound: instrument broadcast (${context.id.ticker})`);
        return true;
    }

    async publishAccountSelection(account: { id: number; displayName?: string } | undefined): Promise<boolean> {
        if (!account || account.id == null) {
            return false;
        }
        if (!this.agent?.broadcast) {
            await this.initialize();
        }
        if (!this.agent?.broadcast) {
            return false;
        }
        const accountId = Number(account.id);
        if (!Number.isFinite(accountId)) {
            return false;
        }
        if (accountId === this.lastPublishedAccountId) {
            return true;
        }
        const context: Fdc3Context = {
            type: 'traderx.account',
            id: {
                accountId: String(accountId)
            },
            name: account.displayName ?? String(accountId)
        };
        const currentChannel = await this.ensureUserChannel(this.agent);
        if (currentChannel?.broadcast) {
            await Promise.resolve(currentChannel.broadcast(context));
        } else {
            await Promise.resolve(this.agent.broadcast(context));
        }
        this.lastPublishedAccountId = accountId;
        this.lastAccountSignature = this.computeAccountSignature(accountId, account.displayName);
        console.info('[fdc3] broadcasted account context', {
            accountId,
            channelId: currentChannel?.id ?? null
        });
        this.statusMessage$.next(`FDC3 outbound: account broadcast (${account.displayName ?? accountId})`);
        return true;
    }

    async raiseIntent(intent: 'ViewChart' | 'ViewQuote' | 'ViewInstrument', traderxTicker: string): Promise<boolean> {
        if (!this.agent?.raiseIntent) {
            await this.initialize();
        }
        if (!this.agent?.raiseIntent) {
            return false;
        }
        const context = intent === 'ViewInstrument'
            ? this.tickerBridge.toViewInstrumentIntentContext(traderxTicker)
            : this.tickerBridge.toInstrumentContext(traderxTicker);
        if (!context?.id?.ticker) {
            return false;
        }
        await Promise.resolve(this.agent.raiseIntent(intent, context));
        console.info('[fdc3] raised intent', { intent, context });
        this.statusMessage$.next(`FDC3 outbound: ${intent} (${context.id.ticker})`);
        return true;
    }

    destroy(): void {
        this.clearListeners();
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = undefined;
        }
        this.agent = undefined;
        this.isAgentAvailable$.next(false);
        this.statusMessage$.next('FDC3 unavailable (running local-only)');
    }

    private async initializeInternal(): Promise<boolean> {
        this.agent = await this.resolveAgent();
        if (!this.agent) {
            this.isAgentAvailable$.next(false);
            this.statusMessage$.next('FDC3 unavailable (running local-only)');
            console.info('[fdc3] desktop agent unavailable; TraderX running in local-only mode');
            this.scheduleReconnect();
            return false;
        }

        try {
            await this.ensureUserChannel(this.agent);
            this.clearListeners();
            await this.registerListeners(this.agent);
            await this.startContextSync(this.agent);
            this.isAgentAvailable$.next(true);
            this.statusMessage$.next('FDC3 connected (Sail agent detected)');
            console.info('[fdc3] listeners registered');
            return true;
        } catch (error) {
            console.warn('[fdc3] failed to register listeners; retrying', error);
            this.clearListeners();
            this.agent = undefined;
            this.isAgentAvailable$.next(false);
            this.statusMessage$.next('FDC3 initialization failed');
            this.scheduleReconnect();
            return false;
        }
    }

    private async resolveAgent(): Promise<Fdc3DesktopAgentLike | undefined> {
        const stableIdentityUrl = this.resolveIdentityUrl();
        for (let attempt = 0; attempt < 10; attempt++) {
            try {
                const agent = await getAgent({
                    timeoutMs: 5000,
                    identityUrl: stableIdentityUrl
                });
                if (agent) {
                    console.info('[fdc3] desktop agent resolved via getAgent()', {
                        attempt: attempt + 1,
                        identityUrl: stableIdentityUrl
                    });
                    return agent as Fdc3DesktopAgentLike;
                }
            } catch (error) {
                console.warn('[fdc3] getAgent() attempt failed', {
                    attempt: attempt + 1,
                    error
                });
            }

            const candidate = (
                window as unknown as {
                    fdc3?: Fdc3DesktopAgentLike & {
                        getAgent?: () => Promise<Fdc3DesktopAgentLike> | Fdc3DesktopAgentLike;
                    };
                }
            ).fdc3;
            if (candidate) {
                if (typeof candidate.getAgent === 'function') {
                    try {
                        const agent = await Promise.resolve(candidate.getAgent());
                        if (agent) {
                            return agent;
                        }
                    } catch (error) {
                        console.warn('[fdc3] window.fdc3.getAgent() failed; falling back to window.fdc3', error);
                    }
                }
                if (candidate.addContextListener || candidate.broadcast || candidate.raiseIntent) {
                    return candidate;
                }
            }

            await this.delay(500);
        }
        return undefined;
    }

    private resolveIdentityUrl(): string {
        const path = String(window.location.pathname || '').replace(/\/+$/, '');
        if (path.endsWith('/mini-traderx')) {
            return `${window.location.origin}/mini-traderx`;
        }
        return `${window.location.origin}/trade`;
    }

    private async ensureUserChannel(agent: Fdc3DesktopAgentLike): Promise<Fdc3ChannelLike | null> {
        if (!agent.getCurrentChannel || !agent.getUserChannels || !agent.joinUserChannel) {
            return null;
        }
        try {
            const current = await Promise.resolve(agent.getCurrentChannel());
            if (current?.id) {
                return current;
            }
            const userChannels = await Promise.resolve(agent.getUserChannels());
            const defaultChannel = Array.isArray(userChannels) ? userChannels[0] : undefined;
            if (!defaultChannel?.id) {
                console.warn('[fdc3] no user channel available to join');
                return null;
            }
            await Promise.resolve(agent.joinUserChannel(defaultChannel.id));
            const joined = await Promise.resolve(agent.getCurrentChannel());
            console.info('[fdc3] joined user channel', {
                channelId: joined?.id ?? defaultChannel.id
            });
            return joined ?? defaultChannel;
        } catch (error) {
            console.warn('[fdc3] failed to ensure user channel', error);
            return null;
        }
    }

    private scheduleReconnect(): void {
        if (this.reconnectTimer) {
            return;
        }
        this.reconnectTimer = setTimeout(() => {
            this.reconnectTimer = undefined;
            this.initialize().catch((error) => {
                console.warn('[fdc3] reconnect attempt failed', error);
                this.scheduleReconnect();
            });
        }, this.reconnectDelayMs);
    }

    private clearListeners(): void {
        if (this.contextSyncInterval) {
            clearInterval(this.contextSyncInterval);
            this.contextSyncInterval = undefined;
        }
        if (this.agent && this.channelChangedHandler) {
            this.agent.removeEventListener?.('userChannelChanged', this.channelChangedHandler);
            this.channelChangedHandler = undefined;
        }
        for (const listener of this.listeners) {
            listener?.unsubscribe?.();
        }
        this.listeners = [];
        this.lastContextSignature = undefined;
        this.lastAccountSignature = undefined;
        this.lastPublishedAccountId = undefined;
    }

    private async registerListeners(agent: Fdc3DesktopAgentLike): Promise<void> {
        await this.addContextListener(agent, 'fdc3.instrument', (context) => {
            this.emitInboundTicker('context', context);
        });
        await this.addContextListener(agent, 'traderx.account', (context) => {
            this.emitInboundAccount(context);
        });

        if (this.isMiniTraderxRoute()) {
            console.info('[fdc3] Mini TraderX registered context listeners only; ticket intents are handled by main TraderX');
            return;
        }

        await this.addIntentListener(agent, 'ViewOrders', (context) => {
            this.emitInboundTicker('ViewOrders', context);
        });
        await this.addIntentListener(agent, 'TraderX.CreateTradeTicket', (context) => {
            this.emitInboundTicker('TraderX.CreateTradeTicket', context);
        });
        await this.addIntentListener(agent, 'TraderX.CreateOrderTicket', (context) => {
            this.emitInboundTicker('TraderX.CreateOrderTicket', context);
        });
    }

    private emitInboundTicker(action: Fdc3InboundAction, context: Fdc3Context): void {
        const ticker = this.tickerBridge.fromInstrumentContext(context);
        if (!ticker) {
            return;
        }
        const resolvedAction = this.resolveInboundAction(action, context);
        this.lastContextSignature = this.computeContextSignature(resolvedAction, ticker, context);
        this.inboundEvents$.next({ action: resolvedAction, ticker });
        this.statusMessage$.next(`FDC3 inbound: ${resolvedAction} (${ticker})`);
        console.info('[fdc3] inbound event', { action: resolvedAction, ticker, context });
    }

    private emitInboundAccount(context: Fdc3Context): void {
        if (context?.type !== 'traderx.account') {
            return;
        }
        const accountId = this.resolveAccountId(context);
        if (accountId == null) {
            return;
        }
        const displayName = typeof context.name === 'string' ? context.name : undefined;
        const signature = this.computeAccountSignature(accountId, displayName);
        if (signature === this.lastAccountSignature) {
            return;
        }
        this.lastAccountSignature = signature;
        this.accountEvents$.next({ accountId, displayName });
        this.statusMessage$.next(`FDC3 inbound: account (${displayName ?? accountId})`);
        console.info('[fdc3] inbound account event', { accountId, displayName, context });
    }

    private resolveInboundAction(action: Fdc3InboundAction, context: Fdc3Context): Fdc3InboundAction {
        if (action !== 'context') {
            return action;
        }
        const actionHint = typeof context?.traderxAction === 'string' ? context.traderxAction : '';
        const normalized = actionHint.trim().toLowerCase();
        if (normalized === 'traderx.createorderticket' || normalized === 'createorderticket') {
            return 'TraderX.CreateOrderTicket';
        }
        if (normalized === 'traderx.createtradeticket' || normalized === 'createtradeticket') {
            return 'TraderX.CreateTradeTicket';
        }
        return action;
    }

    private async addContextListener(
        agent: Fdc3DesktopAgentLike,
        contextType: string,
        handler: (context: Fdc3Context) => void
    ): Promise<void> {
        if (!agent.addContextListener) {
            return;
        }
        const listener = await Promise.resolve(agent.addContextListener(contextType, handler));
        if (listener) {
            this.listeners.push(listener);
        }
    }

    private async addIntentListener(
        agent: Fdc3DesktopAgentLike,
        intent: string,
        handler: (context: Fdc3Context) => void
    ): Promise<void> {
        if (agent.addIntentListenerWithContext) {
            const listener = await Promise.resolve(
                agent.addIntentListenerWithContext(intent, 'fdc3.instrument', handler)
            );
            if (listener) {
                this.listeners.push(listener);
            }
            return;
        }
        if (!agent.addIntentListener) {
            return;
        }
        const listener = await Promise.resolve(agent.addIntentListener(intent, handler));
        if (listener) {
            this.listeners.push(listener);
        }
    }

    private isMiniTraderxRoute(): boolean {
        const path = String(window.location.pathname || '').replace(/\/+$/, '');
        return path.endsWith('/mini-traderx');
    }

    private async delay(ms: number): Promise<void> {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    private async startContextSync(agent: Fdc3DesktopAgentLike): Promise<void> {
        const sync = async () => {
            try {
                await this.syncContextFromActiveChannel(agent);
            } catch (error) {
                console.warn('[fdc3] periodic context sync failed', error);
            }
        };

        this.channelChangedHandler = () => {
            sync().catch((error) => {
                console.warn('[fdc3] channel change context sync failed', error);
            });
        };
        const channelChangedListener = await Promise.resolve(
            agent.addEventListener?.('userChannelChanged', this.channelChangedHandler)
        );
        if (
            channelChangedListener &&
            typeof channelChangedListener === 'object' &&
            typeof channelChangedListener.unsubscribe === 'function'
        ) {
            this.listeners.push(channelChangedListener);
        }

        this.contextSyncInterval = setInterval(() => {
            sync().catch((error) => {
                console.warn('[fdc3] periodic context sync failed', error);
            });
        }, 2000);

        sync().catch((error) => {
            console.warn('[fdc3] initial context sync failed', error);
        });
    }

    private async syncContextFromActiveChannel(agent: Fdc3DesktopAgentLike): Promise<void> {
        const currentChannel = await this.ensureUserChannel(agent);
        await this.syncInstrumentContext(agent, currentChannel);
        await this.syncAccountContext(agent, currentChannel);
    }

    private async syncInstrumentContext(
        agent: Fdc3DesktopAgentLike,
        currentChannel: Fdc3ChannelLike | null
    ): Promise<void> {
        let context: Fdc3Context | null | undefined;
        if (currentChannel?.getCurrentContext) {
            context = await Promise.resolve(currentChannel.getCurrentContext('fdc3.instrument'));
        } else if (agent.getCurrentContext) {
            context = await Promise.resolve(agent.getCurrentContext('fdc3.instrument'));
        } else {
            return;
        }

        const ticker = this.tickerBridge.fromInstrumentContext(context ?? undefined);
        if (!ticker) {
            return;
        }
        const resolvedAction = this.resolveInboundAction('context', context ?? {});
        const signature = this.computeContextSignature(resolvedAction, ticker, context ?? {});
        if (signature === this.lastContextSignature) {
            return;
        }
        this.lastContextSignature = signature;
        this.inboundEvents$.next({ action: resolvedAction, ticker });
        this.statusMessage$.next(`FDC3 inbound: ${resolvedAction} (${ticker})`);
        console.info('[fdc3] inbound event', {
            action: resolvedAction,
            ticker,
            context,
            source: 'context-sync'
        });
    }

    private async syncAccountContext(
        agent: Fdc3DesktopAgentLike,
        currentChannel: Fdc3ChannelLike | null
    ): Promise<void> {
        let context: Fdc3Context | null | undefined;
        if (currentChannel?.getCurrentContext) {
            context = await Promise.resolve(currentChannel.getCurrentContext('traderx.account'));
        } else if (agent.getCurrentContext) {
            context = await Promise.resolve(agent.getCurrentContext('traderx.account'));
        } else {
            return;
        }
        if (!context) {
            return;
        }
        this.emitInboundAccount(context);
    }

    private computeContextSignature(action: Fdc3InboundAction, ticker: string, context: Fdc3Context): string {
        const requestId = typeof context?.traderxActionRequestId === 'string' ? context.traderxActionRequestId : '';
        return `${action}|${ticker}|${requestId}`;
    }

    private resolveAccountId(context: Fdc3Context): number | undefined {
        const raw = context?.id?.accountId ?? context?.id?.id;
        const accountId = Number(raw);
        return Number.isFinite(accountId) ? accountId : undefined;
    }

    private computeAccountSignature(accountId: number, displayName?: string): string {
        return `${accountId}|${displayName ?? ''}`;
    }
}
