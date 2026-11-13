// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

const Empty = new Uint8Array(0);
const TE = new TextEncoder();
const TD = new TextDecoder();
function concat(...bufs) {
    let max = 0;
    for(let i = 0; i < bufs.length; i++){
        max += bufs[i].length;
    }
    const out = new Uint8Array(max);
    let index = 0;
    for(let i = 0; i < bufs.length; i++){
        out.set(bufs[i], index);
        index += bufs[i].length;
    }
    return out;
}
function encode(...a) {
    const bufs = [];
    for(let i = 0; i < a.length; i++){
        bufs.push(TE.encode(a[i]));
    }
    if (bufs.length === 0) {
        return Empty;
    }
    if (bufs.length === 1) {
        return bufs[0];
    }
    return concat(...bufs);
}
function decode(a) {
    if (!a || a.length === 0) {
        return "";
    }
    return TD.decode(a);
}
"use strict";
const digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const base = 36;
const maxSeq = 3656158440062976;
const minInc = 33;
const maxInc = 333;
const totalLen = 12 + 10;
function _getRandomValues(a) {
    for(let i = 0; i < a.length; i++){
        a[i] = Math.floor(Math.random() * 255);
    }
}
function fillRandom(a) {
    if (globalThis?.crypto?.getRandomValues) {
        globalThis.crypto.getRandomValues(a);
    } else {
        _getRandomValues(a);
    }
}
class Nuid {
    buf;
    seq;
    inc;
    inited;
    constructor(){
        this.buf = new Uint8Array(totalLen);
        this.inited = false;
    }
    init() {
        this.inited = true;
        this.setPre();
        this.initSeqAndInc();
        this.fillSeq();
    }
    initSeqAndInc() {
        this.seq = Math.floor(Math.random() * maxSeq);
        this.inc = Math.floor(Math.random() * (maxInc - minInc) + minInc);
    }
    setPre() {
        const cbuf = new Uint8Array(12);
        fillRandom(cbuf);
        for(let i = 0; i < 12; i++){
            const di = cbuf[i] % 36;
            this.buf[i] = digits.charCodeAt(di);
        }
    }
    fillSeq() {
        let n = this.seq;
        for(let i = totalLen - 1; i >= 12; i--){
            this.buf[i] = digits.charCodeAt(n % base);
            n = Math.floor(n / base);
        }
    }
    next() {
        if (!this.inited) {
            this.init();
        }
        this.seq += this.inc;
        if (this.seq > 3656158440062976) {
            this.setPre();
            this.initSeqAndInc();
        }
        this.fillSeq();
        return String.fromCharCode.apply(String, this.buf);
    }
    reset() {
        this.init();
    }
}
const nuid = new Nuid();
var Events;
(function(Events) {
    Events["Disconnect"] = "disconnect";
    Events["Reconnect"] = "reconnect";
    Events["Update"] = "update";
    Events["LDM"] = "ldm";
    Events["Error"] = "error";
})(Events || (Events = {}));
var DebugEvents;
(function(DebugEvents) {
    DebugEvents["Reconnecting"] = "reconnecting";
    DebugEvents["PingTimer"] = "pingTimer";
    DebugEvents["StaleConnection"] = "staleConnection";
    DebugEvents["ClientInitiatedReconnect"] = "client initiated reconnect";
})(DebugEvents || (DebugEvents = {}));
var ErrorCode;
(function(ErrorCode) {
    ErrorCode["ApiError"] = "BAD API";
    ErrorCode["BadAuthentication"] = "BAD_AUTHENTICATION";
    ErrorCode["BadCreds"] = "BAD_CREDS";
    ErrorCode["BadHeader"] = "BAD_HEADER";
    ErrorCode["BadJson"] = "BAD_JSON";
    ErrorCode["BadPayload"] = "BAD_PAYLOAD";
    ErrorCode["BadSubject"] = "BAD_SUBJECT";
    ErrorCode["Cancelled"] = "CANCELLED";
    ErrorCode["ConnectionClosed"] = "CONNECTION_CLOSED";
    ErrorCode["ConnectionDraining"] = "CONNECTION_DRAINING";
    ErrorCode["ConnectionRefused"] = "CONNECTION_REFUSED";
    ErrorCode["ConnectionTimeout"] = "CONNECTION_TIMEOUT";
    ErrorCode["Disconnect"] = "DISCONNECT";
    ErrorCode["InvalidOption"] = "INVALID_OPTION";
    ErrorCode["InvalidPayload"] = "INVALID_PAYLOAD";
    ErrorCode["MaxPayloadExceeded"] = "MAX_PAYLOAD_EXCEEDED";
    ErrorCode["NoResponders"] = "503";
    ErrorCode["NotFunction"] = "NOT_FUNC";
    ErrorCode["RequestError"] = "REQUEST_ERROR";
    ErrorCode["ServerOptionNotAvailable"] = "SERVER_OPT_NA";
    ErrorCode["SubClosed"] = "SUB_CLOSED";
    ErrorCode["SubDraining"] = "SUB_DRAINING";
    ErrorCode["Timeout"] = "TIMEOUT";
    ErrorCode["Tls"] = "TLS";
    ErrorCode["Unknown"] = "UNKNOWN_ERROR";
    ErrorCode["WssRequired"] = "WSS_REQUIRED";
    ErrorCode["JetStreamInvalidAck"] = "JESTREAM_INVALID_ACK";
    ErrorCode["JetStream404NoMessages"] = "404";
    ErrorCode["JetStream408RequestTimeout"] = "408";
    ErrorCode["JetStream409MaxAckPendingExceeded"] = "409";
    ErrorCode["JetStream409"] = "409";
    ErrorCode["JetStreamNotEnabled"] = "503";
    ErrorCode["JetStreamIdleHeartBeat"] = "IDLE_HEARTBEAT";
    ErrorCode["AuthorizationViolation"] = "AUTHORIZATION_VIOLATION";
    ErrorCode["AuthenticationExpired"] = "AUTHENTICATION_EXPIRED";
    ErrorCode["ProtocolError"] = "NATS_PROTOCOL_ERR";
    ErrorCode["PermissionsViolation"] = "PERMISSIONS_VIOLATION";
    ErrorCode["AuthenticationTimeout"] = "AUTHENTICATION_TIMEOUT";
    ErrorCode["AccountExpired"] = "ACCOUNT_EXPIRED";
})(ErrorCode || (ErrorCode = {}));
function isNatsError(err) {
    return typeof err.code === "string";
}
class Messages {
    messages;
    constructor(){
        this.messages = new Map();
        this.messages.set(ErrorCode.InvalidPayload, "Invalid payload type - payloads can be 'binary', 'string', or 'json'");
        this.messages.set(ErrorCode.BadJson, "Bad JSON");
        this.messages.set(ErrorCode.WssRequired, "TLS is required, therefore a secure websocket connection is also required");
    }
    static getMessage(s) {
        return messages.getMessage(s);
    }
    getMessage(s) {
        return this.messages.get(s) || s;
    }
}
const messages = new Messages();
class NatsError extends Error {
    name;
    message;
    code;
    permissionContext;
    chainedError;
    api_error;
    constructor(message, code, chainedError){
        super(message);
        this.name = "NatsError";
        this.message = message;
        this.code = code;
        this.chainedError = chainedError;
    }
    static errorForCode(code, chainedError) {
        const m = Messages.getMessage(code);
        return new NatsError(m, code, chainedError);
    }
    isAuthError() {
        return this.code === ErrorCode.AuthenticationExpired || this.code === ErrorCode.AuthorizationViolation || this.code === ErrorCode.AccountExpired;
    }
    isAuthTimeout() {
        return this.code === ErrorCode.AuthenticationTimeout;
    }
    isPermissionError() {
        return this.code === ErrorCode.PermissionsViolation;
    }
    isProtocolError() {
        return this.code === ErrorCode.ProtocolError;
    }
    isJetStreamError() {
        return this.api_error !== undefined;
    }
    jsError() {
        return this.api_error ? this.api_error : null;
    }
}
var Match;
(function(Match) {
    Match[Match["Exact"] = 0] = "Exact";
    Match[Match["CanonicalMIME"] = 1] = "CanonicalMIME";
    Match[Match["IgnoreCase"] = 2] = "IgnoreCase";
})(Match || (Match = {}));
var RequestStrategy;
(function(RequestStrategy) {
    RequestStrategy["Timer"] = "timer";
    RequestStrategy["Count"] = "count";
    RequestStrategy["JitterTimer"] = "jitterTimer";
    RequestStrategy["SentinelMsg"] = "sentinelMsg";
})(RequestStrategy || (RequestStrategy = {}));
function syncIterator(src) {
    const iter = src[Symbol.asyncIterator]();
    return {
        async next () {
            const m = await iter.next();
            if (m.done) {
                return Promise.resolve(null);
            }
            return Promise.resolve(m.value);
        }
    };
}
var ServiceResponseType;
(function(ServiceResponseType) {
    ServiceResponseType["STATS"] = "io.nats.micro.v1.stats_response";
    ServiceResponseType["INFO"] = "io.nats.micro.v1.info_response";
    ServiceResponseType["PING"] = "io.nats.micro.v1.ping_response";
})(ServiceResponseType || (ServiceResponseType = {}));
const ServiceErrorHeader = "Nats-Service-Error";
const ServiceErrorCodeHeader = "Nats-Service-Error-Code";
class ServiceError extends Error {
    code;
    constructor(code, message){
        super(message);
        this.code = code;
    }
    static isServiceError(msg) {
        return ServiceError.toServiceError(msg) !== null;
    }
    static toServiceError(msg) {
        const scode = msg?.headers?.get(ServiceErrorCodeHeader) || "";
        if (scode !== "") {
            const code = parseInt(scode) || 400;
            const description = msg?.headers?.get(ServiceErrorHeader) || "";
            return new ServiceError(code, description.length ? description : scode);
        }
        return null;
    }
}
function createInbox(prefix = "") {
    prefix = prefix || "_INBOX";
    if (typeof prefix !== "string") {
        throw new Error("prefix must be a string");
    }
    prefix.split(".").forEach((v)=>{
        if (v === "*" || v === ">") {
            throw new Error(`inbox prefixes cannot have wildcards '${prefix}'`);
        }
    });
    return `${prefix}.${nuid.next()}`;
}
const DEFAULT_HOST = "127.0.0.1";
var ServiceVerb;
(function(ServiceVerb) {
    ServiceVerb["PING"] = "PING";
    ServiceVerb["STATS"] = "STATS";
    ServiceVerb["INFO"] = "INFO";
})(ServiceVerb || (ServiceVerb = {}));
function extend(a, ...b) {
    for(let i = 0; i < b.length; i++){
        const o = b[i];
        Object.keys(o).forEach(function(k) {
            a[k] = o[k];
        });
    }
    return a;
}
function render(frame) {
    const cr = "␍";
    const lf = "␊";
    return TD.decode(frame).replace(/\n/g, lf).replace(/\r/g, cr);
}
function timeout(ms, asyncTraces = true) {
    const err = asyncTraces ? NatsError.errorForCode(ErrorCode.Timeout) : null;
    let methods;
    let timer;
    const p = new Promise((_resolve, reject)=>{
        const cancel = ()=>{
            if (timer) {
                clearTimeout(timer);
            }
        };
        methods = {
            cancel
        };
        timer = setTimeout(()=>{
            if (err === null) {
                reject(NatsError.errorForCode(ErrorCode.Timeout));
            } else {
                reject(err);
            }
        }, ms);
    });
    return Object.assign(p, methods);
}
function delay(ms = 0) {
    let methods;
    const p = new Promise((resolve)=>{
        const timer = setTimeout(()=>{
            resolve();
        }, ms);
        const cancel = ()=>{
            if (timer) {
                clearTimeout(timer);
            }
        };
        methods = {
            cancel
        };
    });
    return Object.assign(p, methods);
}
function deadline(p, millis = 1000) {
    const err = new Error(`deadline exceeded`);
    const d = deferred();
    const timer = setTimeout(()=>d.reject(err), millis);
    return Promise.race([
        p,
        d
    ]).finally(()=>clearTimeout(timer));
}
function deferred() {
    let methods = {};
    const p = new Promise((resolve, reject)=>{
        methods = {
            resolve,
            reject
        };
    });
    return Object.assign(p, methods);
}
function shuffle(a) {
    for(let i = a.length - 1; i > 0; i--){
        const j = Math.floor(Math.random() * (i + 1));
        [a[i], a[j]] = [
            a[j],
            a[i]
        ];
    }
    return a;
}
class Perf {
    timers;
    measures;
    constructor(){
        this.timers = new Map();
        this.measures = new Map();
    }
    mark(key) {
        this.timers.set(key, performance.now());
    }
    measure(key, startKey, endKey) {
        const s = this.timers.get(startKey);
        if (s === undefined) {
            throw new Error(`${startKey} is not defined`);
        }
        const e = this.timers.get(endKey);
        if (e === undefined) {
            throw new Error(`${endKey} is not defined`);
        }
        this.measures.set(key, e - s);
    }
    getEntries() {
        const values = [];
        this.measures.forEach((v, k)=>{
            values.push({
                name: k,
                duration: v
            });
        });
        return values;
    }
}
function jitter(n) {
    if (n === 0) {
        return 0;
    }
    return Math.floor(n / 2 + Math.random() * n);
}
function backoff(policy = [
    0,
    250,
    250,
    500,
    500,
    3000,
    5000
]) {
    if (!Array.isArray(policy)) {
        policy = [
            0,
            250,
            250,
            500,
            500,
            3000,
            5000
        ];
    }
    const max = policy.length - 1;
    return {
        backoff (attempt) {
            return jitter(attempt > max ? policy[max] : policy[attempt]);
        }
    };
}
function nanos(millis) {
    return millis * 1000000;
}
function millis(ns) {
    return Math.floor(ns / 1000000);
}
function canonicalMIMEHeaderKey(k) {
    const dash = 45;
    const toLower = 97 - 65;
    let upper = true;
    const buf = new Array(k.length);
    for(let i = 0; i < k.length; i++){
        let c = k.charCodeAt(i);
        if (c === 58 || c < 33 || c > 126) {
            throw new NatsError(`'${k[i]}' is not a valid character for a header key`, ErrorCode.BadHeader);
        }
        if (upper && 97 <= c && c <= 122) {
            c -= toLower;
        } else if (!upper && 65 <= c && c <= 90) {
            c += toLower;
        }
        buf[i] = c;
        upper = c == dash;
    }
    return String.fromCharCode(...buf);
}
function headers(code = 0, description = "") {
    if (code === 0 && description !== "" || code > 0 && description === "") {
        throw new Error("setting status requires both code and description");
    }
    return new MsgHdrsImpl(code, description);
}
const HEADER = "NATS/1.0";
class MsgHdrsImpl {
    _code;
    headers;
    _description;
    constructor(code = 0, description = ""){
        this._code = code;
        this._description = description;
        this.headers = new Map();
    }
    [Symbol.iterator]() {
        return this.headers.entries();
    }
    size() {
        return this.headers.size;
    }
    equals(mh) {
        if (mh && this.headers.size === mh.headers.size && this._code === mh._code) {
            for (const [k, v] of this.headers){
                const a = mh.values(k);
                if (v.length !== a.length) {
                    return false;
                }
                const vv = [
                    ...v
                ].sort();
                const aa = [
                    ...a
                ].sort();
                for(let i = 0; i < vv.length; i++){
                    if (vv[i] !== aa[i]) {
                        return false;
                    }
                }
            }
            return true;
        }
        return false;
    }
    static decode(a) {
        const mh = new MsgHdrsImpl();
        const s = TD.decode(a);
        const lines = s.split("\r\n");
        const h = lines[0];
        if (h !== HEADER) {
            let str = h.replace(HEADER, "").trim();
            if (str.length > 0) {
                mh._code = parseInt(str, 10);
                if (isNaN(mh._code)) {
                    mh._code = 0;
                }
                const scode = mh._code.toString();
                str = str.replace(scode, "");
                mh._description = str.trim();
            }
        }
        if (lines.length >= 1) {
            lines.slice(1).map((s)=>{
                if (s) {
                    const idx = s.indexOf(":");
                    if (idx > -1) {
                        const k = s.slice(0, idx);
                        const v = s.slice(idx + 1).trim();
                        mh.append(k, v);
                    }
                }
            });
        }
        return mh;
    }
    toString() {
        if (this.headers.size === 0 && this._code === 0) {
            return "";
        }
        let s = HEADER;
        if (this._code > 0 && this._description !== "") {
            s += ` ${this._code} ${this._description}`;
        }
        for (const [k, v] of this.headers){
            for(let i = 0; i < v.length; i++){
                s = `${s}\r\n${k}: ${v[i]}`;
            }
        }
        return `${s}\r\n\r\n`;
    }
    encode() {
        return TE.encode(this.toString());
    }
    static validHeaderValue(k) {
        const inv = /[\r\n]/;
        if (inv.test(k)) {
            throw new NatsError("invalid header value - \\r and \\n are not allowed.", ErrorCode.BadHeader);
        }
        return k.trim();
    }
    keys() {
        const keys = [];
        for (const sk of this.headers.keys()){
            keys.push(sk);
        }
        return keys;
    }
    findKeys(k, match = Match.Exact) {
        const keys = this.keys();
        switch(match){
            case Match.Exact:
                return keys.filter((v)=>{
                    return v === k;
                });
            case Match.CanonicalMIME:
                k = canonicalMIMEHeaderKey(k);
                return keys.filter((v)=>{
                    return v === k;
                });
            default:
                {
                    const lci = k.toLowerCase();
                    return keys.filter((v)=>{
                        return lci === v.toLowerCase();
                    });
                }
        }
    }
    get(k, match = Match.Exact) {
        const keys = this.findKeys(k, match);
        if (keys.length) {
            const v = this.headers.get(keys[0]);
            if (v) {
                return Array.isArray(v) ? v[0] : v;
            }
        }
        return "";
    }
    last(k, match = Match.Exact) {
        const keys = this.findKeys(k, match);
        if (keys.length) {
            const v = this.headers.get(keys[0]);
            if (v) {
                return Array.isArray(v) ? v[v.length - 1] : v;
            }
        }
        return "";
    }
    has(k, match = Match.Exact) {
        return this.findKeys(k, match).length > 0;
    }
    set(k, v, match = Match.Exact) {
        this.delete(k, match);
        this.append(k, v, match);
    }
    append(k, v, match = Match.Exact) {
        const ck = canonicalMIMEHeaderKey(k);
        if (match === Match.CanonicalMIME) {
            k = ck;
        }
        const keys = this.findKeys(k, match);
        k = keys.length > 0 ? keys[0] : k;
        const value = MsgHdrsImpl.validHeaderValue(v);
        let a = this.headers.get(k);
        if (!a) {
            a = [];
            this.headers.set(k, a);
        }
        a.push(value);
    }
    values(k, match = Match.Exact) {
        const buf = [];
        const keys = this.findKeys(k, match);
        keys.forEach((v)=>{
            const values = this.headers.get(v);
            if (values) {
                buf.push(...values);
            }
        });
        return buf;
    }
    delete(k, match = Match.Exact) {
        const keys = this.findKeys(k, match);
        keys.forEach((v)=>{
            this.headers.delete(v);
        });
    }
    get hasError() {
        return this._code >= 300;
    }
    get status() {
        return `${this._code} ${this._description}`.trim();
    }
    toRecord() {
        const data = {};
        this.keys().forEach((v)=>{
            data[v] = this.values(v);
        });
        return data;
    }
    get code() {
        return this._code;
    }
    get description() {
        return this._description;
    }
    static fromRecord(r) {
        const h = new MsgHdrsImpl();
        for(const k in r){
            h.headers.set(k, r[k]);
        }
        return h;
    }
}
function StringCodec() {
    return {
        encode (d) {
            return TE.encode(d);
        },
        decode (a) {
            return TD.decode(a);
        }
    };
}
function JSONCodec(reviver) {
    return {
        encode (d) {
            try {
                if (d === undefined) {
                    d = null;
                }
                return TE.encode(JSON.stringify(d));
            } catch (err) {
                throw NatsError.errorForCode(ErrorCode.BadJson, err);
            }
        },
        decode (a) {
            try {
                return JSON.parse(TD.decode(a), reviver);
            } catch (err) {
                throw NatsError.errorForCode(ErrorCode.BadJson, err);
            }
        }
    };
}
function isRequestError(msg) {
    if (msg && msg.data.length === 0 && msg.headers?.code === 503) {
        return NatsError.errorForCode(ErrorCode.NoResponders);
    }
    return null;
}
class MsgImpl {
    _headers;
    _msg;
    _rdata;
    _reply;
    _subject;
    publisher;
    static jc;
    constructor(msg, data, publisher){
        this._msg = msg;
        this._rdata = data;
        this.publisher = publisher;
    }
    get subject() {
        if (this._subject) {
            return this._subject;
        }
        this._subject = TD.decode(this._msg.subject);
        return this._subject;
    }
    get reply() {
        if (this._reply) {
            return this._reply;
        }
        this._reply = TD.decode(this._msg.reply);
        return this._reply;
    }
    get sid() {
        return this._msg.sid;
    }
    get headers() {
        if (this._msg.hdr > -1 && !this._headers) {
            const buf = this._rdata.subarray(0, this._msg.hdr);
            this._headers = MsgHdrsImpl.decode(buf);
        }
        return this._headers;
    }
    get data() {
        if (!this._rdata) {
            return new Uint8Array(0);
        }
        return this._msg.hdr > -1 ? this._rdata.subarray(this._msg.hdr) : this._rdata;
    }
    respond(data = Empty, opts) {
        if (this.reply) {
            this.publisher.publish(this.reply, data, opts);
            return true;
        }
        return false;
    }
    size() {
        const subj = this._msg.subject.length;
        const reply = this._msg.reply?.length || 0;
        const payloadAndHeaders = this._msg.size === -1 ? 0 : this._msg.size;
        return subj + reply + payloadAndHeaders;
    }
    json(reviver) {
        return JSONCodec(reviver).decode(this.data);
    }
    string() {
        return TD.decode(this.data);
    }
    requestInfo() {
        const v = this.headers?.get("Nats-Request-Info");
        if (v) {
            return JSON.parse(v, function(key, value) {
                if ((key === "start" || key === "stop") && value !== "") {
                    return new Date(Date.parse(value));
                }
                return value;
            });
        }
        return null;
    }
}
function validateDurableName(name) {
    return minValidation("durable", name);
}
function validateStreamName(name) {
    return minValidation("stream", name);
}
function minValidation(context, name = "") {
    if (name === "") {
        throw Error(`${context} name required`);
    }
    const bad = [
        ".",
        "*",
        ">",
        "/",
        "\\",
        " ",
        "\t",
        "\n",
        "\r"
    ];
    bad.forEach((v)=>{
        if (name.indexOf(v) !== -1) {
            switch(v){
                case "\n":
                    v = "\\n";
                    break;
                case "\r":
                    v = "\\r";
                    break;
                case "\t":
                    v = "\\t";
                    break;
                default:
            }
            throw Error(`invalid ${context} name - ${context} name cannot contain '${v}'`);
        }
    });
    return "";
}
function validateName(context, name = "") {
    if (name === "") {
        throw Error(`${context} name required`);
    }
    const m = validName(name);
    if (m.length) {
        throw new Error(`invalid ${context} name - ${context} name ${m}`);
    }
}
function validName(name = "") {
    if (name === "") {
        throw Error(`name required`);
    }
    const RE = /^[-\w]+$/g;
    const m = name.match(RE);
    if (m === null) {
        for (const c of name.split("")){
            const mm = c.match(RE);
            if (mm === null) {
                return `cannot contain '${c}'`;
            }
        }
    }
    return "";
}
function isFlowControlMsg(msg) {
    if (msg.data.length > 0) {
        return false;
    }
    const h = msg.headers;
    if (!h) {
        return false;
    }
    return h.code >= 100 && h.code < 200;
}
function isHeartbeatMsg(msg) {
    return isFlowControlMsg(msg) && msg.headers?.description === "Idle Heartbeat";
}
function newJsErrorMsg(code, description, subject) {
    const h = headers(code, description);
    const arg = {
        hdr: 1,
        sid: 0,
        size: 0
    };
    const msg = new MsgImpl(arg, Empty, {});
    msg._headers = h;
    msg._subject = subject;
    return msg;
}
function checkJsError(msg) {
    if (msg.data.length !== 0) {
        return null;
    }
    const h = msg.headers;
    if (!h) {
        return null;
    }
    return checkJsErrorCode(h.code, h.description);
}
var Js409Errors;
(function(Js409Errors) {
    Js409Errors["MaxBatchExceeded"] = "exceeded maxrequestbatch of";
    Js409Errors["MaxExpiresExceeded"] = "exceeded maxrequestexpires of";
    Js409Errors["MaxBytesExceeded"] = "exceeded maxrequestmaxbytes of";
    Js409Errors["MaxMessageSizeExceeded"] = "message size exceeds maxbytes";
    Js409Errors["PushConsumer"] = "consumer is push based";
    Js409Errors["MaxWaitingExceeded"] = "exceeded maxwaiting";
    Js409Errors["IdleHeartbeatMissed"] = "idle heartbeats missed";
    Js409Errors["ConsumerDeleted"] = "consumer deleted";
})(Js409Errors || (Js409Errors = {}));
let MAX_WAITING_FAIL = false;
function isTerminal409(err) {
    if (err.code !== ErrorCode.JetStream409) {
        return false;
    }
    const fatal = [
        Js409Errors.MaxBatchExceeded,
        Js409Errors.MaxExpiresExceeded,
        Js409Errors.MaxBytesExceeded,
        Js409Errors.MaxMessageSizeExceeded,
        Js409Errors.PushConsumer,
        Js409Errors.IdleHeartbeatMissed,
        Js409Errors.ConsumerDeleted
    ];
    if (MAX_WAITING_FAIL) {
        fatal.push(Js409Errors.MaxWaitingExceeded);
    }
    return fatal.find((s)=>{
        return err.message.indexOf(s) !== -1;
    }) !== undefined;
}
function checkJsErrorCode(code, description = "") {
    if (code < 300) {
        return null;
    }
    description = description.toLowerCase();
    switch(code){
        case 404:
            return new NatsError(description, ErrorCode.JetStream404NoMessages);
        case 408:
            return new NatsError(description, ErrorCode.JetStream408RequestTimeout);
        case 409:
            {
                const ec = description.startsWith(Js409Errors.IdleHeartbeatMissed) ? ErrorCode.JetStreamIdleHeartBeat : ErrorCode.JetStream409;
                return new NatsError(description, ec);
            }
        case 503:
            return NatsError.errorForCode(ErrorCode.JetStreamNotEnabled, new Error(description));
        default:
            if (description === "") {
                description = ErrorCode.Unknown;
            }
            return new NatsError(description, `${code}`);
    }
}
class QueuedIteratorImpl {
    inflight;
    processed;
    received;
    noIterator;
    iterClosed;
    done;
    signal;
    yields;
    filtered;
    pendingFiltered;
    ingestionFilterFn;
    protocolFilterFn;
    dispatchedFn;
    ctx;
    _data;
    err;
    time;
    yielding;
    constructor(){
        this.inflight = 0;
        this.filtered = 0;
        this.pendingFiltered = 0;
        this.processed = 0;
        this.received = 0;
        this.noIterator = false;
        this.done = false;
        this.signal = deferred();
        this.yields = [];
        this.iterClosed = deferred();
        this.time = 0;
        this.yielding = false;
    }
    [Symbol.asyncIterator]() {
        return this.iterate();
    }
    push(v) {
        if (this.done) {
            return;
        }
        if (typeof v === "function") {
            this.yields.push(v);
            this.signal.resolve();
            return;
        }
        const { ingest, protocol } = this.ingestionFilterFn ? this.ingestionFilterFn(v, this.ctx || this) : {
            ingest: true,
            protocol: false
        };
        if (ingest) {
            if (protocol) {
                this.filtered++;
                this.pendingFiltered++;
            }
            this.yields.push(v);
            this.signal.resolve();
        }
    }
    async *iterate() {
        if (this.noIterator) {
            throw new NatsError("unsupported iterator", ErrorCode.ApiError);
        }
        if (this.yielding) {
            throw new NatsError("already yielding", ErrorCode.ApiError);
        }
        this.yielding = true;
        try {
            while(true){
                if (this.yields.length === 0) {
                    await this.signal;
                }
                if (this.err) {
                    throw this.err;
                }
                const yields = this.yields;
                this.inflight = yields.length;
                this.yields = [];
                for(let i = 0; i < yields.length; i++){
                    if (typeof yields[i] === "function") {
                        const fn = yields[i];
                        try {
                            fn();
                        } catch (err) {
                            throw err;
                        }
                        if (this.err) {
                            throw this.err;
                        }
                        continue;
                    }
                    const ok = this.protocolFilterFn ? this.protocolFilterFn(yields[i]) : true;
                    if (ok) {
                        this.processed++;
                        const start = Date.now();
                        yield yields[i];
                        this.time = Date.now() - start;
                        if (this.dispatchedFn && yields[i]) {
                            this.dispatchedFn(yields[i]);
                        }
                    } else {
                        this.pendingFiltered--;
                    }
                    this.inflight--;
                }
                if (this.done) {
                    break;
                } else if (this.yields.length === 0) {
                    yields.length = 0;
                    this.yields = yields;
                    this.signal = deferred();
                }
            }
        } finally{
            this.stop();
        }
    }
    stop(err) {
        if (this.done) {
            return;
        }
        this.err = err;
        this.done = true;
        this.signal.resolve();
        this.iterClosed.resolve(err);
    }
    getProcessed() {
        return this.noIterator ? this.received : this.processed;
    }
    getPending() {
        return this.yields.length + this.inflight - this.pendingFiltered;
    }
    getReceived() {
        return this.received - this.filtered;
    }
}
class IdleHeartbeatMonitor {
    interval;
    maxOut;
    cancelAfter;
    timer;
    autoCancelTimer;
    last;
    missed;
    count;
    callback;
    constructor(interval, cb, opts = {
        maxOut: 2
    }){
        this.interval = interval;
        this.maxOut = opts?.maxOut || 2;
        this.cancelAfter = opts?.cancelAfter || 0;
        this.last = Date.now();
        this.missed = 0;
        this.count = 0;
        this.callback = cb;
        this._schedule();
    }
    cancel() {
        if (this.autoCancelTimer) {
            clearTimeout(this.autoCancelTimer);
        }
        if (this.timer) {
            clearInterval(this.timer);
        }
        this.timer = 0;
        this.autoCancelTimer = 0;
        this.missed = 0;
    }
    work() {
        this.last = Date.now();
        this.missed = 0;
    }
    _change(interval, cancelAfter = 0, maxOut = 2) {
        this.interval = interval;
        this.maxOut = maxOut;
        this.cancelAfter = cancelAfter;
        this.restart();
    }
    restart() {
        this.cancel();
        this._schedule();
    }
    _schedule() {
        if (this.cancelAfter > 0) {
            this.autoCancelTimer = setTimeout(()=>{
                this.cancel();
            }, this.cancelAfter);
        }
        this.timer = setInterval(()=>{
            this.count++;
            if (Date.now() - this.last > this.interval) {
                this.missed++;
            }
            if (this.missed >= this.maxOut) {
                try {
                    if (this.callback(this.missed) === true) {
                        this.cancel();
                    }
                } catch (err) {
                    console.log(err);
                }
            }
        }, this.interval);
    }
}
var RetentionPolicy;
(function(RetentionPolicy) {
    RetentionPolicy["Limits"] = "limits";
    RetentionPolicy["Interest"] = "interest";
    RetentionPolicy["Workqueue"] = "workqueue";
})(RetentionPolicy || (RetentionPolicy = {}));
var DiscardPolicy;
(function(DiscardPolicy) {
    DiscardPolicy["Old"] = "old";
    DiscardPolicy["New"] = "new";
})(DiscardPolicy || (DiscardPolicy = {}));
var StorageType;
(function(StorageType) {
    StorageType["File"] = "file";
    StorageType["Memory"] = "memory";
})(StorageType || (StorageType = {}));
var DeliverPolicy;
(function(DeliverPolicy) {
    DeliverPolicy["All"] = "all";
    DeliverPolicy["Last"] = "last";
    DeliverPolicy["New"] = "new";
    DeliverPolicy["StartSequence"] = "by_start_sequence";
    DeliverPolicy["StartTime"] = "by_start_time";
    DeliverPolicy["LastPerSubject"] = "last_per_subject";
})(DeliverPolicy || (DeliverPolicy = {}));
var AckPolicy;
(function(AckPolicy) {
    AckPolicy["None"] = "none";
    AckPolicy["All"] = "all";
    AckPolicy["Explicit"] = "explicit";
    AckPolicy["NotSet"] = "";
})(AckPolicy || (AckPolicy = {}));
var ReplayPolicy;
(function(ReplayPolicy) {
    ReplayPolicy["Instant"] = "instant";
    ReplayPolicy["Original"] = "original";
})(ReplayPolicy || (ReplayPolicy = {}));
var StoreCompression;
(function(StoreCompression) {
    StoreCompression["None"] = "none";
    StoreCompression["S2"] = "s2";
})(StoreCompression || (StoreCompression = {}));
var ConsumerApiAction;
(function(ConsumerApiAction) {
    ConsumerApiAction["CreateOrUpdate"] = "";
    ConsumerApiAction["Update"] = "update";
    ConsumerApiAction["Create"] = "create";
})(ConsumerApiAction || (ConsumerApiAction = {}));
function defaultConsumer(name, opts = {}) {
    return Object.assign({
        name: name,
        deliver_policy: DeliverPolicy.All,
        ack_policy: AckPolicy.Explicit,
        ack_wait: nanos(30 * 1000),
        replay_policy: ReplayPolicy.Instant
    }, opts);
}
var AdvisoryKind;
(function(AdvisoryKind) {
    AdvisoryKind["API"] = "api_audit";
    AdvisoryKind["StreamAction"] = "stream_action";
    AdvisoryKind["ConsumerAction"] = "consumer_action";
    AdvisoryKind["SnapshotCreate"] = "snapshot_create";
    AdvisoryKind["SnapshotComplete"] = "snapshot_complete";
    AdvisoryKind["RestoreCreate"] = "restore_create";
    AdvisoryKind["RestoreComplete"] = "restore_complete";
    AdvisoryKind["MaxDeliver"] = "max_deliver";
    AdvisoryKind["Terminated"] = "terminated";
    AdvisoryKind["Ack"] = "consumer_ack";
    AdvisoryKind["StreamLeaderElected"] = "stream_leader_elected";
    AdvisoryKind["StreamQuorumLost"] = "stream_quorum_lost";
    AdvisoryKind["ConsumerLeaderElected"] = "consumer_leader_elected";
    AdvisoryKind["ConsumerQuorumLost"] = "consumer_quorum_lost";
})(AdvisoryKind || (AdvisoryKind = {}));
var JsHeaders;
(function(JsHeaders) {
    JsHeaders["StreamSourceHdr"] = "Nats-Stream-Source";
    JsHeaders["LastConsumerSeqHdr"] = "Nats-Last-Consumer";
    JsHeaders["LastStreamSeqHdr"] = "Nats-Last-Stream";
    JsHeaders["ConsumerStalledHdr"] = "Nats-Consumer-Stalled";
    JsHeaders["MessageSizeHdr"] = "Nats-Msg-Size";
    JsHeaders["RollupHdr"] = "Nats-Rollup";
    JsHeaders["RollupValueSubject"] = "sub";
    JsHeaders["RollupValueAll"] = "all";
    JsHeaders["PendingMessagesHdr"] = "Nats-Pending-Messages";
    JsHeaders["PendingBytesHdr"] = "Nats-Pending-Bytes";
})(JsHeaders || (JsHeaders = {}));
var KvWatchInclude;
(function(KvWatchInclude) {
    KvWatchInclude["LastValue"] = "";
    KvWatchInclude["AllHistory"] = "history";
    KvWatchInclude["UpdatesOnly"] = "updates";
})(KvWatchInclude || (KvWatchInclude = {}));
var DirectMsgHeaders;
(function(DirectMsgHeaders) {
    DirectMsgHeaders["Stream"] = "Nats-Stream";
    DirectMsgHeaders["Sequence"] = "Nats-Sequence";
    DirectMsgHeaders["TimeStamp"] = "Nats-Time-Stamp";
    DirectMsgHeaders["Subject"] = "Nats-Subject";
})(DirectMsgHeaders || (DirectMsgHeaders = {}));
var RepublishHeaders;
(function(RepublishHeaders) {
    RepublishHeaders["Stream"] = "Nats-Stream";
    RepublishHeaders["Subject"] = "Nats-Subject";
    RepublishHeaders["Sequence"] = "Nats-Sequence";
    RepublishHeaders["LastSequence"] = "Nats-Last-Sequence";
    RepublishHeaders["Size"] = "Nats-Msg-Size";
})(RepublishHeaders || (RepublishHeaders = {}));
const kvPrefix = "KV_";
class ConsumerOptsBuilderImpl {
    config;
    ordered;
    mack;
    stream;
    callbackFn;
    max;
    qname;
    isBind;
    filters;
    constructor(opts){
        this.stream = "";
        this.mack = false;
        this.ordered = false;
        this.config = defaultConsumer("", opts || {});
    }
    getOpts() {
        const o = {};
        o.config = Object.assign({}, this.config);
        if (o.config.filter_subject) {
            this.filterSubject(o.config.filter_subject);
            o.config.filter_subject = undefined;
        }
        if (o.config.filter_subjects) {
            o.config.filter_subjects?.forEach((v)=>{
                this.filterSubject(v);
            });
            o.config.filter_subjects = undefined;
        }
        o.mack = this.mack;
        o.stream = this.stream;
        o.callbackFn = this.callbackFn;
        o.max = this.max;
        o.queue = this.qname;
        o.ordered = this.ordered;
        o.config.ack_policy = o.ordered ? AckPolicy.None : o.config.ack_policy;
        o.isBind = o.isBind || false;
        if (this.filters) {
            switch(this.filters.length){
                case 0:
                    break;
                case 1:
                    o.config.filter_subject = this.filters[0];
                    break;
                default:
                    o.config.filter_subjects = this.filters;
            }
        }
        return o;
    }
    description(description) {
        this.config.description = description;
        return this;
    }
    deliverTo(subject) {
        this.config.deliver_subject = subject;
        return this;
    }
    durable(name) {
        validateDurableName(name);
        this.config.durable_name = name;
        return this;
    }
    startSequence(seq) {
        if (seq <= 0) {
            throw new Error("sequence must be greater than 0");
        }
        this.config.deliver_policy = DeliverPolicy.StartSequence;
        this.config.opt_start_seq = seq;
        return this;
    }
    startTime(time) {
        this.config.deliver_policy = DeliverPolicy.StartTime;
        this.config.opt_start_time = time.toISOString();
        return this;
    }
    deliverAll() {
        this.config.deliver_policy = DeliverPolicy.All;
        return this;
    }
    deliverLastPerSubject() {
        this.config.deliver_policy = DeliverPolicy.LastPerSubject;
        return this;
    }
    deliverLast() {
        this.config.deliver_policy = DeliverPolicy.Last;
        return this;
    }
    deliverNew() {
        this.config.deliver_policy = DeliverPolicy.New;
        return this;
    }
    startAtTimeDelta(millis) {
        this.startTime(new Date(Date.now() - millis));
        return this;
    }
    headersOnly() {
        this.config.headers_only = true;
        return this;
    }
    ackNone() {
        this.config.ack_policy = AckPolicy.None;
        return this;
    }
    ackAll() {
        this.config.ack_policy = AckPolicy.All;
        return this;
    }
    ackExplicit() {
        this.config.ack_policy = AckPolicy.Explicit;
        return this;
    }
    ackWait(millis) {
        this.config.ack_wait = nanos(millis);
        return this;
    }
    maxDeliver(max) {
        this.config.max_deliver = max;
        return this;
    }
    filterSubject(s) {
        this.filters = this.filters || [];
        this.filters.push(s);
        return this;
    }
    replayInstantly() {
        this.config.replay_policy = ReplayPolicy.Instant;
        return this;
    }
    replayOriginal() {
        this.config.replay_policy = ReplayPolicy.Original;
        return this;
    }
    sample(n) {
        n = Math.trunc(n);
        if (n < 0 || n > 100) {
            throw new Error(`value must be between 0-100`);
        }
        this.config.sample_freq = `${n}%`;
        return this;
    }
    limit(n) {
        this.config.rate_limit_bps = n;
        return this;
    }
    maxWaiting(max) {
        this.config.max_waiting = max;
        return this;
    }
    maxAckPending(max) {
        this.config.max_ack_pending = max;
        return this;
    }
    idleHeartbeat(millis) {
        this.config.idle_heartbeat = nanos(millis);
        return this;
    }
    flowControl() {
        this.config.flow_control = true;
        return this;
    }
    deliverGroup(name) {
        this.queue(name);
        return this;
    }
    manualAck() {
        this.mack = true;
        return this;
    }
    maxMessages(max) {
        this.max = max;
        return this;
    }
    callback(fn) {
        this.callbackFn = fn;
        return this;
    }
    queue(n) {
        this.qname = n;
        this.config.deliver_group = n;
        return this;
    }
    orderedConsumer() {
        this.ordered = true;
        return this;
    }
    bind(stream, durable) {
        this.stream = stream;
        this.config.durable_name = durable;
        this.isBind = true;
        return this;
    }
    bindStream(stream) {
        this.stream = stream;
        return this;
    }
    inactiveEphemeralThreshold(millis) {
        this.config.inactive_threshold = nanos(millis);
        return this;
    }
    maxPullBatch(n) {
        this.config.max_batch = n;
        return this;
    }
    maxPullRequestExpires(millis) {
        this.config.max_expires = nanos(millis);
        return this;
    }
    memory() {
        this.config.mem_storage = true;
        return this;
    }
    numReplicas(n) {
        this.config.num_replicas = n;
        return this;
    }
    consumerName(n) {
        this.config.name = n;
        return this;
    }
}
function consumerOpts(opts) {
    return new ConsumerOptsBuilderImpl(opts);
}
function isConsumerOptsBuilder(o) {
    return typeof o.getOpts === "function";
}
class Base64Codec {
    static encode(bytes) {
        if (typeof bytes === "string") {
            return btoa(bytes);
        }
        const a = Array.from(bytes);
        return btoa(String.fromCharCode(...a));
    }
    static decode(s, binary = false) {
        const bin = atob(s);
        if (!binary) {
            return bin;
        }
        return Uint8Array.from(bin, (c)=>c.charCodeAt(0));
    }
}
class Base64UrlPaddedCodec {
    static encode(bytes) {
        return Base64UrlPaddedCodec.toB64URLEncoding(Base64Codec.encode(bytes));
    }
    static decode(s, binary = false) {
        return Base64UrlPaddedCodec.decode(Base64UrlPaddedCodec.fromB64URLEncoding(s), binary);
    }
    static toB64URLEncoding(b64str) {
        return b64str.replace(/\+/g, "-").replace(/\//g, "_");
    }
    static fromB64URLEncoding(b64str) {
        return b64str.replace(/_/g, "/").replace(/-/g, "+");
    }
}
class DataBuffer {
    buffers;
    byteLength;
    constructor(){
        this.buffers = [];
        this.byteLength = 0;
    }
    static concat(...bufs) {
        let max = 0;
        for(let i = 0; i < bufs.length; i++){
            max += bufs[i].length;
        }
        const out = new Uint8Array(max);
        let index = 0;
        for(let i = 0; i < bufs.length; i++){
            out.set(bufs[i], index);
            index += bufs[i].length;
        }
        return out;
    }
    static fromAscii(m) {
        if (!m) {
            m = "";
        }
        return TE.encode(m);
    }
    static toAscii(a) {
        return TD.decode(a);
    }
    reset() {
        this.buffers.length = 0;
        this.byteLength = 0;
    }
    pack() {
        if (this.buffers.length > 1) {
            const v = new Uint8Array(this.byteLength);
            let index = 0;
            for(let i = 0; i < this.buffers.length; i++){
                v.set(this.buffers[i], index);
                index += this.buffers[i].length;
            }
            this.buffers.length = 0;
            this.buffers.push(v);
        }
    }
    shift() {
        if (this.buffers.length) {
            const a = this.buffers.shift();
            if (a) {
                this.byteLength -= a.length;
                return a;
            }
        }
        return new Uint8Array(0);
    }
    drain(n) {
        if (this.buffers.length) {
            this.pack();
            const v = this.buffers.pop();
            if (v) {
                const max = this.byteLength;
                if (n === undefined || n > max) {
                    n = max;
                }
                const d = v.subarray(0, n);
                if (max > n) {
                    this.buffers.push(v.subarray(n));
                }
                this.byteLength = max - n;
                return d;
            }
        }
        return new Uint8Array(0);
    }
    fill(a, ...bufs) {
        if (a) {
            this.buffers.push(a);
            this.byteLength += a.length;
        }
        for(let i = 0; i < bufs.length; i++){
            if (bufs[i] && bufs[i].length) {
                this.buffers.push(bufs[i]);
                this.byteLength += bufs[i].length;
            }
        }
    }
    peek() {
        if (this.buffers.length) {
            this.pack();
            return this.buffers[0];
        }
        return new Uint8Array(0);
    }
    size() {
        return this.byteLength;
    }
    length() {
        return this.buffers.length;
    }
}
function t(t, e) {
    return e.forEach(function(e) {
        e && "string" != typeof e && !Array.isArray(e) && Object.keys(e).forEach(function(r) {
            if ("default" !== r && !(r in t)) {
                var i = Object.getOwnPropertyDescriptor(e, r);
                Object.defineProperty(t, r, i.get ? i : {
                    enumerable: !0,
                    get: function() {
                        return e[r];
                    }
                });
            }
        });
    }), Object.freeze(t);
}
var e = "undefined" != typeof global ? global : "undefined" != typeof self ? self : "undefined" != typeof window ? window : {};
function r() {
    throw new Error("setTimeout has not been defined");
}
function i() {
    throw new Error("clearTimeout has not been defined");
}
var h = r, s = i;
function n(t) {
    if (h === setTimeout) return setTimeout(t, 0);
    if ((h === r || !h) && setTimeout) return h = setTimeout, setTimeout(t, 0);
    try {
        return h(t, 0);
    } catch (e) {
        try {
            return h.call(null, t, 0);
        } catch (e) {
            return h.call(this, t, 0);
        }
    }
}
"function" == typeof e.setTimeout && (h = setTimeout), "function" == typeof e.clearTimeout && (s = clearTimeout);
var o, a = [], f = !1, u = -1;
function c() {
    f && o && (f = !1, o.length ? a = o.concat(a) : u = -1, a.length && l());
}
function l() {
    if (!f) {
        var t = n(c);
        f = !0;
        for(var e = a.length; e;){
            for(o = a, a = []; ++u < e;)o && o[u].run();
            u = -1, e = a.length;
        }
        o = null, f = !1, function(t) {
            if (s === clearTimeout) return clearTimeout(t);
            if ((s === i || !s) && clearTimeout) return s = clearTimeout, clearTimeout(t);
            try {
                return s(t);
            } catch (e) {
                try {
                    return s.call(null, t);
                } catch (e) {
                    return s.call(this, t);
                }
            }
        }(t);
    }
}
function y(t, e) {
    this.fun = t, this.array = e;
}
y.prototype.run = function() {
    this.fun.apply(null, this.array);
};
function p() {}
var d = p, w = p, b = p, v = p, A = p, g = p, _ = p;
var m = e.performance || {}, O = m.now || m.mozNow || m.msNow || m.oNow || m.webkitNow || function() {
    return (new Date).getTime();
};
var B = new Date;
var E = {
    nextTick: function(t) {
        var e = new Array(arguments.length - 1);
        if (arguments.length > 1) for(var r = 1; r < arguments.length; r++)e[r - 1] = arguments[r];
        a.push(new y(t, e)), 1 !== a.length || f || n(l);
    },
    title: "browser",
    browser: !0,
    env: {},
    argv: [],
    version: "",
    versions: {},
    on: d,
    addListener: w,
    once: b,
    off: v,
    removeListener: A,
    removeAllListeners: g,
    emit: _,
    binding: function(t) {
        throw new Error("process.binding is not supported");
    },
    cwd: function() {
        return "/";
    },
    chdir: function(t) {
        throw new Error("process.chdir is not supported");
    },
    umask: function() {
        return 0;
    },
    hrtime: function(t) {
        var e = .001 * O.call(m), r = Math.floor(e), i = Math.floor(e % 1 * 1e9);
        return t && (r -= t[0], (i -= t[1]) < 0 && (r--, i += 1e9)), [
            r,
            i
        ];
    },
    platform: "browser",
    release: {},
    config: {},
    uptime: function() {
        return (new Date - B) / 1e3;
    }
}, S = "undefined" != typeof globalThis ? globalThis : "undefined" != typeof window ? window : "undefined" != typeof global ? global : "undefined" != typeof self ? self : {};
function T(t) {
    if (t.__esModule) return t;
    var e = Object.defineProperty({}, "__esModule", {
        value: !0
    });
    return Object.keys(t).forEach(function(r) {
        var i = Object.getOwnPropertyDescriptor(t, r);
        Object.defineProperty(e, r, i.get ? i : {
            enumerable: !0,
            get: function() {
                return t[r];
            }
        });
    }), e;
}
var k, x = {
    exports: {}
}, j = {}, N = T(t({
    __proto__: null,
    default: j
}, [
    j
]));
k = x, function() {
    var t = "input is invalid type", e = "object" == typeof window, r = e ? window : {};
    r.JS_SHA256_NO_WINDOW && (e = !1);
    var i = !e && "object" == typeof self, h = !r.JS_SHA256_NO_NODE_JS && E.versions && E.versions.node;
    h ? r = S : i && (r = self);
    var s = !r.JS_SHA256_NO_COMMON_JS && k.exports, n = !r.JS_SHA256_NO_ARRAY_BUFFER && "undefined" != typeof ArrayBuffer, o = "0123456789abcdef".split(""), a = [
        -2147483648,
        8388608,
        32768,
        128
    ], f = [
        24,
        16,
        8,
        0
    ], u = [
        1116352408,
        1899447441,
        3049323471,
        3921009573,
        961987163,
        1508970993,
        2453635748,
        2870763221,
        3624381080,
        310598401,
        607225278,
        1426881987,
        1925078388,
        2162078206,
        2614888103,
        3248222580,
        3835390401,
        4022224774,
        264347078,
        604807628,
        770255983,
        1249150122,
        1555081692,
        1996064986,
        2554220882,
        2821834349,
        2952996808,
        3210313671,
        3336571891,
        3584528711,
        113926993,
        338241895,
        666307205,
        773529912,
        1294757372,
        1396182291,
        1695183700,
        1986661051,
        2177026350,
        2456956037,
        2730485921,
        2820302411,
        3259730800,
        3345764771,
        3516065817,
        3600352804,
        4094571909,
        275423344,
        430227734,
        506948616,
        659060556,
        883997877,
        958139571,
        1322822218,
        1537002063,
        1747873779,
        1955562222,
        2024104815,
        2227730452,
        2361852424,
        2428436474,
        2756734187,
        3204031479,
        3329325298
    ], c = [
        "hex",
        "array",
        "digest",
        "arrayBuffer"
    ], l = [];
    !r.JS_SHA256_NO_NODE_JS && Array.isArray || (Array.isArray = function(t) {
        return "[object Array]" === Object.prototype.toString.call(t);
    }), !n || !r.JS_SHA256_NO_ARRAY_BUFFER_IS_VIEW && ArrayBuffer.isView || (ArrayBuffer.isView = function(t) {
        return "object" == typeof t && t.buffer && t.buffer.constructor === ArrayBuffer;
    });
    var y = function(t, e) {
        return function(r) {
            return new v(e, !0).update(r)[t]();
        };
    }, p = function(t) {
        var e = y("hex", t);
        h && (e = d(e, t)), e.create = function() {
            return new v(t);
        }, e.update = function(t) {
            return e.create().update(t);
        };
        for(var r = 0; r < c.length; ++r){
            var i = c[r];
            e[i] = y(i, t);
        }
        return e;
    }, d = function(e, i) {
        var h, s = N, n = N.Buffer, o = i ? "sha224" : "sha256";
        return h = n.from && !r.JS_SHA256_NO_BUFFER_FROM ? n.from : function(t) {
            return new n(t);
        }, function(r) {
            if ("string" == typeof r) return s.createHash(o).update(r, "utf8").digest("hex");
            if (null == r) throw new Error(t);
            return r.constructor === ArrayBuffer && (r = new Uint8Array(r)), Array.isArray(r) || ArrayBuffer.isView(r) || r.constructor === n ? s.createHash(o).update(h(r)).digest("hex") : e(r);
        };
    }, w = function(t, e) {
        return function(r, i) {
            return new A(r, e, !0).update(i)[t]();
        };
    }, b = function(t) {
        var e = w("hex", t);
        e.create = function(e) {
            return new A(e, t);
        }, e.update = function(t, r) {
            return e.create(t).update(r);
        };
        for(var r = 0; r < c.length; ++r){
            var i = c[r];
            e[i] = w(i, t);
        }
        return e;
    };
    function v(t, e) {
        e ? (l[0] = l[16] = l[1] = l[2] = l[3] = l[4] = l[5] = l[6] = l[7] = l[8] = l[9] = l[10] = l[11] = l[12] = l[13] = l[14] = l[15] = 0, this.blocks = l) : this.blocks = [
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ], t ? (this.h0 = 3238371032, this.h1 = 914150663, this.h2 = 812702999, this.h3 = 4144912697, this.h4 = 4290775857, this.h5 = 1750603025, this.h6 = 1694076839, this.h7 = 3204075428) : (this.h0 = 1779033703, this.h1 = 3144134277, this.h2 = 1013904242, this.h3 = 2773480762, this.h4 = 1359893119, this.h5 = 2600822924, this.h6 = 528734635, this.h7 = 1541459225), this.block = this.start = this.bytes = this.hBytes = 0, this.finalized = this.hashed = !1, this.first = !0, this.is224 = t;
    }
    function A(e, r, i) {
        var h, s = typeof e;
        if ("string" === s) {
            var o, a = [], f = e.length, u = 0;
            for(h = 0; h < f; ++h)(o = e.charCodeAt(h)) < 128 ? a[u++] = o : o < 2048 ? (a[u++] = 192 | o >>> 6, a[u++] = 128 | 63 & o) : o < 55296 || o >= 57344 ? (a[u++] = 224 | o >>> 12, a[u++] = 128 | o >>> 6 & 63, a[u++] = 128 | 63 & o) : (o = 65536 + ((1023 & o) << 10 | 1023 & e.charCodeAt(++h)), a[u++] = 240 | o >>> 18, a[u++] = 128 | o >>> 12 & 63, a[u++] = 128 | o >>> 6 & 63, a[u++] = 128 | 63 & o);
            e = a;
        } else {
            if ("object" !== s) throw new Error(t);
            if (null === e) throw new Error(t);
            if (n && e.constructor === ArrayBuffer) e = new Uint8Array(e);
            else if (!(Array.isArray(e) || n && ArrayBuffer.isView(e))) throw new Error(t);
        }
        e.length > 64 && (e = new v(r, !0).update(e).array());
        var c = [], l = [];
        for(h = 0; h < 64; ++h){
            var y = e[h] || 0;
            c[h] = 92 ^ y, l[h] = 54 ^ y;
        }
        v.call(this, r, i), this.update(l), this.oKeyPad = c, this.inner = !0, this.sharedMemory = i;
    }
    v.prototype.update = function(e) {
        if (!this.finalized) {
            var r, i = typeof e;
            if ("string" !== i) {
                if ("object" !== i) throw new Error(t);
                if (null === e) throw new Error(t);
                if (n && e.constructor === ArrayBuffer) e = new Uint8Array(e);
                else if (!(Array.isArray(e) || n && ArrayBuffer.isView(e))) throw new Error(t);
                r = !0;
            }
            for(var h, s, o = 0, a = e.length, u = this.blocks; o < a;){
                if (this.hashed && (this.hashed = !1, u[0] = this.block, this.block = u[16] = u[1] = u[2] = u[3] = u[4] = u[5] = u[6] = u[7] = u[8] = u[9] = u[10] = u[11] = u[12] = u[13] = u[14] = u[15] = 0), r) for(s = this.start; o < a && s < 64; ++o)u[s >>> 2] |= e[o] << f[3 & s++];
                else for(s = this.start; o < a && s < 64; ++o)(h = e.charCodeAt(o)) < 128 ? u[s >>> 2] |= h << f[3 & s++] : h < 2048 ? (u[s >>> 2] |= (192 | h >>> 6) << f[3 & s++], u[s >>> 2] |= (128 | 63 & h) << f[3 & s++]) : h < 55296 || h >= 57344 ? (u[s >>> 2] |= (224 | h >>> 12) << f[3 & s++], u[s >>> 2] |= (128 | h >>> 6 & 63) << f[3 & s++], u[s >>> 2] |= (128 | 63 & h) << f[3 & s++]) : (h = 65536 + ((1023 & h) << 10 | 1023 & e.charCodeAt(++o)), u[s >>> 2] |= (240 | h >>> 18) << f[3 & s++], u[s >>> 2] |= (128 | h >>> 12 & 63) << f[3 & s++], u[s >>> 2] |= (128 | h >>> 6 & 63) << f[3 & s++], u[s >>> 2] |= (128 | 63 & h) << f[3 & s++]);
                this.lastByteIndex = s, this.bytes += s - this.start, s >= 64 ? (this.block = u[16], this.start = s - 64, this.hash(), this.hashed = !0) : this.start = s;
            }
            return this.bytes > 4294967295 && (this.hBytes += this.bytes / 4294967296 | 0, this.bytes = this.bytes % 4294967296), this;
        }
    }, v.prototype.finalize = function() {
        if (!this.finalized) {
            this.finalized = !0;
            var t = this.blocks, e = this.lastByteIndex;
            t[16] = this.block, t[e >>> 2] |= a[3 & e], this.block = t[16], e >= 56 && (this.hashed || this.hash(), t[0] = this.block, t[16] = t[1] = t[2] = t[3] = t[4] = t[5] = t[6] = t[7] = t[8] = t[9] = t[10] = t[11] = t[12] = t[13] = t[14] = t[15] = 0), t[14] = this.hBytes << 3 | this.bytes >>> 29, t[15] = this.bytes << 3, this.hash();
        }
    }, v.prototype.hash = function() {
        var t, e, r, i, h, s, n, o, a, f = this.h0, c = this.h1, l = this.h2, y = this.h3, p = this.h4, d = this.h5, w = this.h6, b = this.h7, v = this.blocks;
        for(t = 16; t < 64; ++t)e = ((h = v[t - 15]) >>> 7 | h << 25) ^ (h >>> 18 | h << 14) ^ h >>> 3, r = ((h = v[t - 2]) >>> 17 | h << 15) ^ (h >>> 19 | h << 13) ^ h >>> 10, v[t] = v[t - 16] + e + v[t - 7] + r | 0;
        for(a = c & l, t = 0; t < 64; t += 4)this.first ? (this.is224 ? (s = 300032, b = (h = v[0] - 1413257819) - 150054599 | 0, y = h + 24177077 | 0) : (s = 704751109, b = (h = v[0] - 210244248) - 1521486534 | 0, y = h + 143694565 | 0), this.first = !1) : (e = (f >>> 2 | f << 30) ^ (f >>> 13 | f << 19) ^ (f >>> 22 | f << 10), i = (s = f & c) ^ f & l ^ a, b = y + (h = b + (r = (p >>> 6 | p << 26) ^ (p >>> 11 | p << 21) ^ (p >>> 25 | p << 7)) + (p & d ^ ~p & w) + u[t] + v[t]) | 0, y = h + (e + i) | 0), e = (y >>> 2 | y << 30) ^ (y >>> 13 | y << 19) ^ (y >>> 22 | y << 10), i = (n = y & f) ^ y & c ^ s, w = l + (h = w + (r = (b >>> 6 | b << 26) ^ (b >>> 11 | b << 21) ^ (b >>> 25 | b << 7)) + (b & p ^ ~b & d) + u[t + 1] + v[t + 1]) | 0, e = ((l = h + (e + i) | 0) >>> 2 | l << 30) ^ (l >>> 13 | l << 19) ^ (l >>> 22 | l << 10), i = (o = l & y) ^ l & f ^ n, d = c + (h = d + (r = (w >>> 6 | w << 26) ^ (w >>> 11 | w << 21) ^ (w >>> 25 | w << 7)) + (w & b ^ ~w & p) + u[t + 2] + v[t + 2]) | 0, e = ((c = h + (e + i) | 0) >>> 2 | c << 30) ^ (c >>> 13 | c << 19) ^ (c >>> 22 | c << 10), i = (a = c & l) ^ c & y ^ o, p = f + (h = p + (r = (d >>> 6 | d << 26) ^ (d >>> 11 | d << 21) ^ (d >>> 25 | d << 7)) + (d & w ^ ~d & b) + u[t + 3] + v[t + 3]) | 0, f = h + (e + i) | 0, this.chromeBugWorkAround = !0;
        this.h0 = this.h0 + f | 0, this.h1 = this.h1 + c | 0, this.h2 = this.h2 + l | 0, this.h3 = this.h3 + y | 0, this.h4 = this.h4 + p | 0, this.h5 = this.h5 + d | 0, this.h6 = this.h6 + w | 0, this.h7 = this.h7 + b | 0;
    }, v.prototype.hex = function() {
        this.finalize();
        var t = this.h0, e = this.h1, r = this.h2, i = this.h3, h = this.h4, s = this.h5, n = this.h6, a = this.h7, f = o[t >>> 28 & 15] + o[t >>> 24 & 15] + o[t >>> 20 & 15] + o[t >>> 16 & 15] + o[t >>> 12 & 15] + o[t >>> 8 & 15] + o[t >>> 4 & 15] + o[15 & t] + o[e >>> 28 & 15] + o[e >>> 24 & 15] + o[e >>> 20 & 15] + o[e >>> 16 & 15] + o[e >>> 12 & 15] + o[e >>> 8 & 15] + o[e >>> 4 & 15] + o[15 & e] + o[r >>> 28 & 15] + o[r >>> 24 & 15] + o[r >>> 20 & 15] + o[r >>> 16 & 15] + o[r >>> 12 & 15] + o[r >>> 8 & 15] + o[r >>> 4 & 15] + o[15 & r] + o[i >>> 28 & 15] + o[i >>> 24 & 15] + o[i >>> 20 & 15] + o[i >>> 16 & 15] + o[i >>> 12 & 15] + o[i >>> 8 & 15] + o[i >>> 4 & 15] + o[15 & i] + o[h >>> 28 & 15] + o[h >>> 24 & 15] + o[h >>> 20 & 15] + o[h >>> 16 & 15] + o[h >>> 12 & 15] + o[h >>> 8 & 15] + o[h >>> 4 & 15] + o[15 & h] + o[s >>> 28 & 15] + o[s >>> 24 & 15] + o[s >>> 20 & 15] + o[s >>> 16 & 15] + o[s >>> 12 & 15] + o[s >>> 8 & 15] + o[s >>> 4 & 15] + o[15 & s] + o[n >>> 28 & 15] + o[n >>> 24 & 15] + o[n >>> 20 & 15] + o[n >>> 16 & 15] + o[n >>> 12 & 15] + o[n >>> 8 & 15] + o[n >>> 4 & 15] + o[15 & n];
        return this.is224 || (f += o[a >>> 28 & 15] + o[a >>> 24 & 15] + o[a >>> 20 & 15] + o[a >>> 16 & 15] + o[a >>> 12 & 15] + o[a >>> 8 & 15] + o[a >>> 4 & 15] + o[15 & a]), f;
    }, v.prototype.toString = v.prototype.hex, v.prototype.digest = function() {
        this.finalize();
        var t = this.h0, e = this.h1, r = this.h2, i = this.h3, h = this.h4, s = this.h5, n = this.h6, o = this.h7, a = [
            t >>> 24 & 255,
            t >>> 16 & 255,
            t >>> 8 & 255,
            255 & t,
            e >>> 24 & 255,
            e >>> 16 & 255,
            e >>> 8 & 255,
            255 & e,
            r >>> 24 & 255,
            r >>> 16 & 255,
            r >>> 8 & 255,
            255 & r,
            i >>> 24 & 255,
            i >>> 16 & 255,
            i >>> 8 & 255,
            255 & i,
            h >>> 24 & 255,
            h >>> 16 & 255,
            h >>> 8 & 255,
            255 & h,
            s >>> 24 & 255,
            s >>> 16 & 255,
            s >>> 8 & 255,
            255 & s,
            n >>> 24 & 255,
            n >>> 16 & 255,
            n >>> 8 & 255,
            255 & n
        ];
        return this.is224 || a.push(o >>> 24 & 255, o >>> 16 & 255, o >>> 8 & 255, 255 & o), a;
    }, v.prototype.array = v.prototype.digest, v.prototype.arrayBuffer = function() {
        this.finalize();
        var t = new ArrayBuffer(this.is224 ? 28 : 32), e = new DataView(t);
        return e.setUint32(0, this.h0), e.setUint32(4, this.h1), e.setUint32(8, this.h2), e.setUint32(12, this.h3), e.setUint32(16, this.h4), e.setUint32(20, this.h5), e.setUint32(24, this.h6), this.is224 || e.setUint32(28, this.h7), t;
    }, A.prototype = new v, A.prototype.finalize = function() {
        if (v.prototype.finalize.call(this), this.inner) {
            this.inner = !1;
            var t = this.array();
            v.call(this, this.is224, this.sharedMemory), this.update(this.oKeyPad), this.update(t), v.prototype.finalize.call(this);
        }
    };
    var g = p();
    g.sha256 = g, g.sha224 = p(!0), g.sha256.hmac = b(), g.sha224.hmac = b(!0), s ? k.exports = g : (r.sha256 = g.sha256, r.sha224 = g.sha224);
}();
var U = x.exports, z = x.exports.sha224, J = x.exports.sha256;
function parseSha256(s) {
    return toByteArray(s);
}
function isHex(s) {
    const hexRegex = /^[0-9A-Fa-f]+$/;
    if (!hexRegex.test(s)) {
        return false;
    }
    const isAllUpperCase = /^[0-9A-F]+$/.test(s);
    const isAllLowerCase = /^[0-9a-f]+$/.test(s);
    if (!(isAllUpperCase || isAllLowerCase)) {
        return false;
    }
    return s.length % 2 === 0;
}
function isBase64(s) {
    return /^[A-Za-z0-9\-_]*(={0,2})?$/.test(s) || /^[A-Za-z0-9+/]*(={0,2})?$/.test(s);
}
function detectEncoding(input) {
    if (isHex(input)) {
        return "hex";
    } else if (isBase64(input)) {
        return "b64";
    }
    return "";
}
function hexToByteArray(s) {
    if (s.length % 2 !== 0) {
        throw new Error("hex string must have an even length");
    }
    const a = new Uint8Array(s.length / 2);
    for(let i = 0; i < s.length; i += 2){
        a[i / 2] = parseInt(s.substring(i, i + 2), 16);
    }
    return a;
}
function base64ToByteArray(s) {
    s = s.replace(/-/g, "+");
    s = s.replace(/_/g, "/");
    const sbin = atob(s);
    return Uint8Array.from(sbin, (c)=>c.charCodeAt(0));
}
function toByteArray(input) {
    const encoding = detectEncoding(input);
    switch(encoding){
        case "hex":
            return hexToByteArray(input);
        case "b64":
            return base64ToByteArray(input);
    }
    return null;
}
function checkSha256(a, b) {
    const aBytes = typeof a === "string" ? parseSha256(a) : a;
    const bBytes = typeof b === "string" ? parseSha256(b) : b;
    if (aBytes === null || bBytes === null) {
        return false;
    }
    if (aBytes.length !== bBytes.length) {
        return false;
    }
    for(let i = 0; i < aBytes.length; i++){
        if (aBytes[i] !== bBytes[i]) {
            return false;
        }
    }
    return true;
}
class BaseRequest {
    token;
    received;
    ctx;
    requestSubject;
    mux;
    constructor(mux, requestSubject, asyncTraces = true){
        this.mux = mux;
        this.requestSubject = requestSubject;
        this.received = 0;
        this.token = nuid.next();
        if (asyncTraces) {
            this.ctx = new Error();
        }
    }
}
class RequestMany extends BaseRequest {
    callback;
    done;
    timer;
    max;
    opts;
    constructor(mux, requestSubject, opts = {
        maxWait: 1000
    }){
        super(mux, requestSubject);
        this.opts = opts;
        if (typeof this.opts.callback !== "function") {
            throw new Error("callback is required");
        }
        this.callback = this.opts.callback;
        this.max = typeof opts.maxMessages === "number" && opts.maxMessages > 0 ? opts.maxMessages : -1;
        this.done = deferred();
        this.done.then(()=>{
            this.callback(null, null);
        });
        this.timer = setTimeout(()=>{
            this.cancel();
        }, opts.maxWait);
    }
    cancel(err) {
        if (err) {
            this.callback(err, null);
        }
        clearTimeout(this.timer);
        this.mux.cancel(this);
        this.done.resolve();
    }
    resolver(err, msg) {
        if (err) {
            if (this.ctx) {
                err.stack += `\n\n${this.ctx.stack}`;
            }
            this.cancel(err);
        } else {
            this.callback(null, msg);
            if (this.opts.strategy === RequestStrategy.Count) {
                this.max--;
                if (this.max === 0) {
                    this.cancel();
                }
            }
            if (this.opts.strategy === RequestStrategy.JitterTimer) {
                clearTimeout(this.timer);
                this.timer = setTimeout(()=>{
                    this.cancel();
                }, this.opts.jitter || 300);
            }
            if (this.opts.strategy === RequestStrategy.SentinelMsg) {
                if (msg && msg.data.length === 0) {
                    this.cancel();
                }
            }
        }
    }
}
class RequestOne extends BaseRequest {
    deferred;
    timer;
    constructor(mux, requestSubject, opts = {
        timeout: 1000
    }, asyncTraces = true){
        super(mux, requestSubject, asyncTraces);
        this.deferred = deferred();
        this.timer = timeout(opts.timeout, asyncTraces);
    }
    resolver(err, msg) {
        if (this.timer) {
            this.timer.cancel();
        }
        if (err) {
            if (this.ctx) {
                err.stack += `\n\n${this.ctx.stack}`;
            }
            this.deferred.reject(err);
        } else {
            this.deferred.resolve(msg);
        }
        this.cancel();
    }
    cancel(err) {
        if (this.timer) {
            this.timer.cancel();
        }
        this.mux.cancel(this);
        this.deferred.reject(err ? err : NatsError.errorForCode(ErrorCode.Cancelled));
    }
}
const defaultPrefix = "$JS.API";
function defaultJsOptions(opts) {
    opts = opts || {};
    if (opts.domain) {
        opts.apiPrefix = `$JS.${opts.domain}.API`;
        delete opts.domain;
    }
    return extend({
        apiPrefix: defaultPrefix,
        timeout: 5000
    }, opts);
}
class BaseApiClient {
    nc;
    opts;
    prefix;
    timeout;
    jc;
    constructor(nc, opts){
        this.nc = nc;
        this.opts = defaultJsOptions(opts);
        this._parseOpts();
        this.prefix = this.opts.apiPrefix;
        this.timeout = this.opts.timeout;
        this.jc = JSONCodec();
    }
    getOptions() {
        return Object.assign({}, this.opts);
    }
    _parseOpts() {
        let prefix = this.opts.apiPrefix;
        if (!prefix || prefix.length === 0) {
            throw new Error("invalid empty prefix");
        }
        const c = prefix[prefix.length - 1];
        if (c === ".") {
            prefix = prefix.substr(0, prefix.length - 1);
        }
        this.opts.apiPrefix = prefix;
    }
    async _request(subj, data = null, opts) {
        opts = opts || {};
        opts.timeout = this.timeout;
        let a = Empty;
        if (data) {
            a = this.jc.encode(data);
        }
        let { retries } = opts;
        retries = retries || 1;
        retries = retries === -1 ? Number.MAX_SAFE_INTEGER : retries;
        const bo = backoff();
        for(let i = 0; i < retries; i++){
            try {
                const m = await this.nc.request(subj, a, opts);
                return this.parseJsResponse(m);
            } catch (err) {
                const ne = err;
                if ((ne.code === "503" || ne.code === ErrorCode.Timeout) && i + 1 < retries) {
                    await delay(bo.backoff(i));
                } else {
                    throw err;
                }
            }
        }
    }
    async findStream(subject) {
        const q = {
            subject
        };
        const r = await this._request(`${this.prefix}.STREAM.NAMES`, q);
        const names = r;
        if (!names.streams || names.streams.length !== 1) {
            throw new Error("no stream matches subject");
        }
        return names.streams[0];
    }
    getConnection() {
        return this.nc;
    }
    parseJsResponse(m) {
        const v = this.jc.decode(m.data);
        const r = v;
        if (r.error) {
            const err = checkJsErrorCode(r.error.code, r.error.description);
            if (err !== null) {
                err.api_error = r.error;
                throw err;
            }
        }
        return v;
    }
}
class ListerImpl {
    err;
    offset;
    pageInfo;
    subject;
    jsm;
    filter;
    payload;
    constructor(subject, filter, jsm, payload){
        if (!subject) {
            throw new Error("subject is required");
        }
        this.subject = subject;
        this.jsm = jsm;
        this.offset = 0;
        this.pageInfo = {};
        this.filter = filter;
        this.payload = payload || {};
    }
    async next() {
        if (this.err) {
            return [];
        }
        if (this.pageInfo && this.offset >= this.pageInfo.total) {
            return [];
        }
        const offset = {
            offset: this.offset
        };
        if (this.payload) {
            Object.assign(offset, this.payload);
        }
        try {
            const r = await this.jsm._request(this.subject, offset, {
                timeout: this.jsm.timeout
            });
            this.pageInfo = r;
            const count = this.countResponse(r);
            if (count === 0) {
                return [];
            }
            this.offset += count;
            const a = this.filter(r);
            return a;
        } catch (err) {
            this.err = err;
            throw err;
        }
    }
    countResponse(r) {
        switch(r?.type){
            case "io.nats.jetstream.api.v1.stream_names_response":
            case "io.nats.jetstream.api.v1.stream_list_response":
                return r.streams?.length || 0;
            case "io.nats.jetstream.api.v1.consumer_list_response":
                return r.consumers?.length || 0;
            default:
                console.error(`jslister.ts: unknown API response for paged output: ${r?.type}`);
                return r.streams?.length || 0;
        }
        return 0;
    }
    async *[Symbol.asyncIterator]() {
        let page = await this.next();
        while(page.length > 0){
            for (const item of page){
                yield item;
            }
            page = await this.next();
        }
    }
}
function parseSemVer(s = "") {
    const m = s.match(/(\d+).(\d+).(\d+)/);
    if (m) {
        return {
            major: parseInt(m[1]),
            minor: parseInt(m[2]),
            micro: parseInt(m[3])
        };
    }
    throw new Error(`'${s}' is not a semver value`);
}
function compare(a, b) {
    if (a.major < b.major) return -1;
    if (a.major > b.major) return 1;
    if (a.minor < b.minor) return -1;
    if (a.minor > b.minor) return 1;
    if (a.micro < b.micro) return -1;
    if (a.micro > b.micro) return 1;
    return 0;
}
var Feature;
(function(Feature) {
    Feature["JS_KV"] = "js_kv";
    Feature["JS_OBJECTSTORE"] = "js_objectstore";
    Feature["JS_PULL_MAX_BYTES"] = "js_pull_max_bytes";
    Feature["JS_NEW_CONSUMER_CREATE_API"] = "js_new_consumer_create";
    Feature["JS_ALLOW_DIRECT"] = "js_allow_direct";
    Feature["JS_MULTIPLE_CONSUMER_FILTER"] = "js_multiple_consumer_filter";
    Feature["JS_SIMPLIFICATION"] = "js_simplification";
    Feature["JS_STREAM_CONSUMER_METADATA"] = "js_stream_consumer_metadata";
    Feature["JS_CONSUMER_FILTER_SUBJECTS"] = "js_consumer_filter_subjects";
    Feature["JS_STREAM_FIRST_SEQ"] = "js_stream_first_seq";
    Feature["JS_STREAM_SUBJECT_TRANSFORM"] = "js_stream_subject_transform";
    Feature["JS_STREAM_SOURCE_SUBJECT_TRANSFORM"] = "js_stream_source_subject_transform";
    Feature["JS_STREAM_COMPRESSION"] = "js_stream_compression";
    Feature["JS_DEFAULT_CONSUMER_LIMITS"] = "js_default_consumer_limits";
    Feature["JS_BATCH_DIRECT_GET"] = "js_batch_direct_get";
})(Feature || (Feature = {}));
class Features {
    server;
    features;
    disabled;
    constructor(v){
        this.features = new Map();
        this.disabled = [];
        this.update(v);
    }
    resetDisabled() {
        this.disabled.length = 0;
        this.update(this.server);
    }
    disable(f) {
        this.disabled.push(f);
        this.update(this.server);
    }
    isDisabled(f) {
        return this.disabled.indexOf(f) !== -1;
    }
    update(v) {
        if (typeof v === "string") {
            v = parseSemVer(v);
        }
        this.server = v;
        this.set(Feature.JS_KV, "2.6.2");
        this.set(Feature.JS_OBJECTSTORE, "2.6.3");
        this.set(Feature.JS_PULL_MAX_BYTES, "2.8.3");
        this.set(Feature.JS_NEW_CONSUMER_CREATE_API, "2.9.0");
        this.set(Feature.JS_ALLOW_DIRECT, "2.9.0");
        this.set(Feature.JS_MULTIPLE_CONSUMER_FILTER, "2.10.0");
        this.set(Feature.JS_SIMPLIFICATION, "2.9.4");
        this.set(Feature.JS_STREAM_CONSUMER_METADATA, "2.10.0");
        this.set(Feature.JS_CONSUMER_FILTER_SUBJECTS, "2.10.0");
        this.set(Feature.JS_STREAM_FIRST_SEQ, "2.10.0");
        this.set(Feature.JS_STREAM_SUBJECT_TRANSFORM, "2.10.0");
        this.set(Feature.JS_STREAM_SOURCE_SUBJECT_TRANSFORM, "2.10.0");
        this.set(Feature.JS_STREAM_COMPRESSION, "2.10.0");
        this.set(Feature.JS_DEFAULT_CONSUMER_LIMITS, "2.10.0");
        this.set(Feature.JS_BATCH_DIRECT_GET, "2.11.0");
        this.disabled.forEach((f)=>{
            this.features.delete(f);
        });
    }
    set(f, requires) {
        this.features.set(f, {
            min: requires,
            ok: compare(this.server, parseSemVer(requires)) >= 0
        });
    }
    get(f) {
        return this.features.get(f) || {
            min: "unknown",
            ok: false
        };
    }
    supports(f) {
        return this.get(f)?.ok || false;
    }
    require(v) {
        if (typeof v === "string") {
            v = parseSemVer(v);
        }
        return compare(this.server, v) >= 0;
    }
}
class ConsumerAPIImpl extends BaseApiClient {
    constructor(nc, opts){
        super(nc, opts);
    }
    async add(stream, cfg, action = ConsumerApiAction.Create) {
        validateStreamName(stream);
        if (cfg.deliver_group && cfg.flow_control) {
            throw new Error("jetstream flow control is not supported with queue groups");
        }
        if (cfg.deliver_group && cfg.idle_heartbeat) {
            throw new Error("jetstream idle heartbeat is not supported with queue groups");
        }
        const cr = {};
        cr.config = cfg;
        cr.stream_name = stream;
        cr.action = action;
        if (cr.config.durable_name) {
            validateDurableName(cr.config.durable_name);
        }
        const nci = this.nc;
        let { min, ok: newAPI } = nci.features.get(Feature.JS_NEW_CONSUMER_CREATE_API);
        const name = cfg.name === "" ? undefined : cfg.name;
        if (name && !newAPI) {
            throw new Error(`consumer 'name' requires server ${min}`);
        }
        if (name) {
            try {
                minValidation("name", name);
            } catch (err) {
                const m = err.message;
                const idx = m.indexOf("cannot contain");
                if (idx !== -1) {
                    throw new Error(`consumer 'name' ${m.substring(idx)}`);
                }
                throw err;
            }
        }
        let subj;
        let consumerName = "";
        if (Array.isArray(cfg.filter_subjects)) {
            const { min, ok } = nci.features.get(Feature.JS_MULTIPLE_CONSUMER_FILTER);
            if (!ok) {
                throw new Error(`consumer 'filter_subjects' requires server ${min}`);
            }
            newAPI = false;
        }
        if (cfg.metadata) {
            const { min, ok } = nci.features.get(Feature.JS_STREAM_CONSUMER_METADATA);
            if (!ok) {
                throw new Error(`consumer 'metadata' requires server ${min}`);
            }
        }
        if (newAPI) {
            consumerName = cfg.name ?? cfg.durable_name ?? "";
        }
        if (consumerName !== "") {
            let fs = cfg.filter_subject ?? undefined;
            if (fs === ">") {
                fs = undefined;
            }
            subj = fs !== undefined ? `${this.prefix}.CONSUMER.CREATE.${stream}.${consumerName}.${fs}` : `${this.prefix}.CONSUMER.CREATE.${stream}.${consumerName}`;
        } else {
            subj = cfg.durable_name ? `${this.prefix}.CONSUMER.DURABLE.CREATE.${stream}.${cfg.durable_name}` : `${this.prefix}.CONSUMER.CREATE.${stream}`;
        }
        const r = await this._request(subj, cr);
        return r;
    }
    async update(stream, durable, cfg) {
        const ci = await this.info(stream, durable);
        const changable = cfg;
        return this.add(stream, Object.assign(ci.config, changable), ConsumerApiAction.Update);
    }
    async info(stream, name) {
        validateStreamName(stream);
        validateDurableName(name);
        const r = await this._request(`${this.prefix}.CONSUMER.INFO.${stream}.${name}`);
        return r;
    }
    async delete(stream, name) {
        validateStreamName(stream);
        validateDurableName(name);
        const r = await this._request(`${this.prefix}.CONSUMER.DELETE.${stream}.${name}`);
        const cr = r;
        return cr.success;
    }
    list(stream) {
        validateStreamName(stream);
        const filter = (v)=>{
            const clr = v;
            return clr.consumers;
        };
        const subj = `${this.prefix}.CONSUMER.LIST.${stream}`;
        return new ListerImpl(subj, filter, this);
    }
    pause(stream, name, until) {
        const subj = `${this.prefix}.CONSUMER.PAUSE.${stream}.${name}`;
        const opts = {
            pause_until: until.toISOString()
        };
        return this._request(subj, opts);
    }
    resume(stream, name) {
        return this.pause(stream, name, new Date(0));
    }
}
function checkFn(fn, name, required = false) {
    if (required === true && !fn) {
        throw NatsError.errorForCode(ErrorCode.ApiError, new Error(`${name} is not a function`));
    }
    if (fn && typeof fn !== "function") {
        throw NatsError.errorForCode(ErrorCode.ApiError, new Error(`${name} is not a function`));
    }
}
class TypedSubscription extends QueuedIteratorImpl {
    sub;
    adapter;
    subIterDone;
    constructor(nc, subject, opts){
        super();
        checkFn(opts.adapter, "adapter", true);
        this.adapter = opts.adapter;
        if (opts.callback) {
            checkFn(opts.callback, "callback");
        }
        this.noIterator = typeof opts.callback === "function";
        if (opts.ingestionFilterFn) {
            checkFn(opts.ingestionFilterFn, "ingestionFilterFn");
            this.ingestionFilterFn = opts.ingestionFilterFn;
        }
        if (opts.protocolFilterFn) {
            checkFn(opts.protocolFilterFn, "protocolFilterFn");
            this.protocolFilterFn = opts.protocolFilterFn;
        }
        if (opts.dispatchedFn) {
            checkFn(opts.dispatchedFn, "dispatchedFn");
            this.dispatchedFn = opts.dispatchedFn;
        }
        if (opts.cleanupFn) {
            checkFn(opts.cleanupFn, "cleanupFn");
        }
        let callback = (err, msg)=>{
            this.callback(err, msg);
        };
        if (opts.callback) {
            const uh = opts.callback;
            callback = (err, msg)=>{
                const [jer, tm] = this.adapter(err, msg);
                if (jer) {
                    uh(jer, null);
                    return;
                }
                const { ingest } = this.ingestionFilterFn ? this.ingestionFilterFn(tm, this) : {
                    ingest: true
                };
                if (ingest) {
                    const ok = this.protocolFilterFn ? this.protocolFilterFn(tm) : true;
                    if (ok) {
                        uh(jer, tm);
                        if (this.dispatchedFn && tm) {
                            this.dispatchedFn(tm);
                        }
                    }
                }
            };
        }
        const { max, queue, timeout } = opts;
        const sopts = {
            queue,
            timeout,
            callback
        };
        if (max && max > 0) {
            sopts.max = max;
        }
        this.sub = nc.subscribe(subject, sopts);
        if (opts.cleanupFn) {
            this.sub.cleanupFn = opts.cleanupFn;
        }
        if (!this.noIterator) {
            this.iterClosed.then(()=>{
                this.unsubscribe();
            });
        }
        this.subIterDone = deferred();
        Promise.all([
            this.sub.closed,
            this.iterClosed
        ]).then(()=>{
            this.subIterDone.resolve();
        }).catch(()=>{
            this.subIterDone.resolve();
        });
        (async (s)=>{
            await s.closed;
            this.stop();
        })(this.sub).then().catch();
    }
    unsubscribe(max) {
        this.sub.unsubscribe(max);
    }
    drain() {
        return this.sub.drain();
    }
    isDraining() {
        return this.sub.isDraining();
    }
    isClosed() {
        return this.sub.isClosed();
    }
    callback(e, msg) {
        this.sub.cancelTimeout();
        const [err, tm] = this.adapter(e, msg);
        if (err) {
            this.stop(err);
        }
        if (tm) {
            this.push(tm);
        }
    }
    getSubject() {
        return this.sub.getSubject();
    }
    getReceived() {
        return this.sub.getReceived();
    }
    getProcessed() {
        return this.sub.getProcessed();
    }
    getPending() {
        return this.sub.getPending();
    }
    getID() {
        return this.sub.getID();
    }
    getMax() {
        return this.sub.getMax();
    }
    get closed() {
        return this.sub.closed;
    }
}
let transportConfig;
function setTransportFactory(config) {
    transportConfig = config;
}
function defaultPort() {
    return transportConfig !== undefined && transportConfig.defaultPort !== undefined ? transportConfig.defaultPort : 4222;
}
function getUrlParseFn() {
    return transportConfig !== undefined && transportConfig.urlParseFn ? transportConfig.urlParseFn : undefined;
}
function newTransport() {
    if (!transportConfig || typeof transportConfig.factory !== "function") {
        throw new Error("transport fn is not set");
    }
    return transportConfig.factory();
}
function getResolveFn() {
    return transportConfig !== undefined && transportConfig.dnsResolveFn ? transportConfig.dnsResolveFn : undefined;
}
const CR_LF = "\r\n";
CR_LF.length;
const CRLF = DataBuffer.fromAscii(CR_LF);
const CR = new Uint8Array(CRLF)[0];
const LF = new Uint8Array(CRLF)[1];
function protoLen(ba) {
    for(let i = 0; i < ba.length; i++){
        const n = i + 1;
        if (ba.byteLength > n && ba[i] === CR && ba[n] === LF) {
            return n + 1;
        }
    }
    return 0;
}
function extractProtocolMessage(a) {
    const len = protoLen(a);
    if (len > 0) {
        const ba = new Uint8Array(a);
        const out = ba.slice(0, len);
        return TD.decode(out);
    }
    return "";
}
const IPv4LEN = 4;
const ASCII0 = 48;
const ASCIIA = 65;
const ASCIIa = 97;
function ipV4(a, b, c, d) {
    const ip = new Uint8Array(16);
    const prefix = [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0xff,
        0xff
    ];
    prefix.forEach((v, idx)=>{
        ip[idx] = v;
    });
    ip[12] = a;
    ip[13] = b;
    ip[14] = c;
    ip[15] = d;
    return ip;
}
function isIP(h) {
    return parseIP(h) !== undefined;
}
function parseIP(h) {
    for(let i = 0; i < h.length; i++){
        switch(h[i]){
            case ".":
                return parseIPv4(h);
            case ":":
                return parseIPv6(h);
        }
    }
    return;
}
function parseIPv4(s) {
    const ip = new Uint8Array(4);
    for(let i = 0; i < 4; i++){
        if (s.length === 0) {
            return undefined;
        }
        if (i > 0) {
            if (s[0] !== ".") {
                return undefined;
            }
            s = s.substring(1);
        }
        const { n, c, ok } = dtoi(s);
        if (!ok || n > 0xFF) {
            return undefined;
        }
        s = s.substring(c);
        ip[i] = n;
    }
    return ipV4(ip[0], ip[1], ip[2], ip[3]);
}
function parseIPv6(s) {
    const ip = new Uint8Array(16);
    let ellipsis = -1;
    if (s.length >= 2 && s[0] === ":" && s[1] === ":") {
        ellipsis = 0;
        s = s.substring(2);
        if (s.length === 0) {
            return ip;
        }
    }
    let i = 0;
    while(i < 16){
        const { n, c, ok } = xtoi(s);
        if (!ok || n > 0xFFFF) {
            return undefined;
        }
        if (c < s.length && s[c] === ".") {
            if (ellipsis < 0 && i != 16 - 4) {
                return undefined;
            }
            if (i + 4 > 16) {
                return undefined;
            }
            const ip4 = parseIPv4(s);
            if (ip4 === undefined) {
                return undefined;
            }
            ip[i] = ip4[12];
            ip[i + 1] = ip4[13];
            ip[i + 2] = ip4[14];
            ip[i + 3] = ip4[15];
            s = "";
            i += IPv4LEN;
            break;
        }
        ip[i] = n >> 8;
        ip[i + 1] = n;
        i += 2;
        s = s.substring(c);
        if (s.length === 0) {
            break;
        }
        if (s[0] !== ":" || s.length == 1) {
            return undefined;
        }
        s = s.substring(1);
        if (s[0] === ":") {
            if (ellipsis >= 0) {
                return undefined;
            }
            ellipsis = i;
            s = s.substring(1);
            if (s.length === 0) {
                break;
            }
        }
    }
    if (s.length !== 0) {
        return undefined;
    }
    if (i < 16) {
        if (ellipsis < 0) {
            return undefined;
        }
        const n = 16 - i;
        for(let j = i - 1; j >= ellipsis; j--){
            ip[j + n] = ip[j];
        }
        for(let j = ellipsis + n - 1; j >= ellipsis; j--){
            ip[j] = 0;
        }
    } else if (ellipsis >= 0) {
        return undefined;
    }
    return ip;
}
function dtoi(s) {
    let i = 0;
    let n = 0;
    for(i = 0; i < s.length && 48 <= s.charCodeAt(i) && s.charCodeAt(i) <= 57; i++){
        n = n * 10 + (s.charCodeAt(i) - ASCII0);
        if (n >= 0xFFFFFF) {
            return {
                n: 0xFFFFFF,
                c: i,
                ok: false
            };
        }
    }
    if (i === 0) {
        return {
            n: 0,
            c: 0,
            ok: false
        };
    }
    return {
        n: n,
        c: i,
        ok: true
    };
}
function xtoi(s) {
    let n = 0;
    let i = 0;
    for(i = 0; i < s.length; i++){
        if (48 <= s.charCodeAt(i) && s.charCodeAt(i) <= 57) {
            n *= 16;
            n += s.charCodeAt(i) - ASCII0;
        } else if (97 <= s.charCodeAt(i) && s.charCodeAt(i) <= 102) {
            n *= 16;
            n += s.charCodeAt(i) - ASCIIa + 10;
        } else if (65 <= s.charCodeAt(i) && s.charCodeAt(i) <= 70) {
            n *= 16;
            n += s.charCodeAt(i) - ASCIIA + 10;
        } else {
            break;
        }
        if (n >= 0xFFFFFF) {
            return {
                n: 0,
                c: i,
                ok: false
            };
        }
    }
    if (i === 0) {
        return {
            n: 0,
            c: i,
            ok: false
        };
    }
    return {
        n: n,
        c: i,
        ok: true
    };
}
function isIPV4OrHostname(hp) {
    if (hp.indexOf("[") !== -1 || hp.indexOf("::") !== -1) {
        return false;
    }
    if (hp.indexOf(".") !== -1) {
        return true;
    }
    if (hp.split(":").length <= 2) {
        return true;
    }
    return false;
}
function isIPV6(hp) {
    return !isIPV4OrHostname(hp);
}
function filterIpv6MappedToIpv4(hp) {
    const prefix = "::FFFF:";
    const idx = hp.toUpperCase().indexOf(prefix);
    if (idx !== -1 && hp.indexOf(".") !== -1) {
        let ip = hp.substring(idx + prefix.length);
        ip = ip.replace("[", "");
        return ip.replace("]", "");
    }
    return hp;
}
function hostPort(u) {
    u = u.trim();
    if (u.match(/^(.*:\/\/)(.*)/m)) {
        u = u.replace(/^(.*:\/\/)(.*)/gm, "$2");
    }
    u = filterIpv6MappedToIpv4(u);
    if (isIPV6(u) && u.indexOf("[") === -1) {
        u = `[${u}]`;
    }
    const op = isIPV6(u) ? u.match(/(]:)(\d+)/) : u.match(/(:)(\d+)/);
    const port = op && op.length === 3 && op[1] && op[2] ? parseInt(op[2]) : 4222;
    const protocol = port === 80 ? "https" : "http";
    const url = new URL(`${protocol}://${u}`);
    url.port = `${port}`;
    let hostname = url.hostname;
    if (hostname.charAt(0) === "[") {
        hostname = hostname.substring(1, hostname.length - 1);
    }
    const listen = url.host;
    return {
        listen,
        hostname,
        port
    };
}
class ServerImpl {
    src;
    listen;
    hostname;
    port;
    didConnect;
    reconnects;
    lastConnect;
    gossiped;
    tlsName;
    resolves;
    constructor(u, gossiped = false){
        this.src = u;
        this.tlsName = "";
        const v = hostPort(u);
        this.listen = v.listen;
        this.hostname = v.hostname;
        this.port = v.port;
        this.didConnect = false;
        this.reconnects = 0;
        this.lastConnect = 0;
        this.gossiped = gossiped;
    }
    toString() {
        return this.listen;
    }
    async resolve(opts) {
        if (!opts.fn || opts.resolve === false) {
            return [
                this
            ];
        }
        const buf = [];
        if (isIP(this.hostname)) {
            return [
                this
            ];
        } else {
            const ips = await opts.fn(this.hostname);
            if (opts.debug) {
                console.log(`resolve ${this.hostname} = ${ips.join(",")}`);
            }
            for (const ip of ips){
                const proto = this.port === 80 ? "https" : "http";
                const url = new URL(`${proto}://${isIPV6(ip) ? "[" + ip + "]" : ip}`);
                url.port = `${this.port}`;
                const ss = new ServerImpl(url.host, false);
                ss.tlsName = this.hostname;
                buf.push(ss);
            }
        }
        if (opts.randomize) {
            shuffle(buf);
        }
        this.resolves = buf;
        return buf;
    }
}
class Servers {
    firstSelect;
    servers;
    currentServer;
    tlsName;
    randomize;
    constructor(listens = [], opts = {}){
        this.firstSelect = true;
        this.servers = [];
        this.tlsName = "";
        this.randomize = opts.randomize || false;
        const urlParseFn = getUrlParseFn();
        if (listens) {
            listens.forEach((hp)=>{
                hp = urlParseFn ? urlParseFn(hp) : hp;
                this.servers.push(new ServerImpl(hp));
            });
            if (this.randomize) {
                this.servers = shuffle(this.servers);
            }
        }
        if (this.servers.length === 0) {
            this.addServer(`${DEFAULT_HOST}:${defaultPort()}`, false);
        }
        this.currentServer = this.servers[0];
    }
    clear() {
        this.servers.length = 0;
    }
    updateTLSName() {
        const cs = this.getCurrentServer();
        if (!isIP(cs.hostname)) {
            this.tlsName = cs.hostname;
            this.servers.forEach((s)=>{
                if (s.gossiped) {
                    s.tlsName = this.tlsName;
                }
            });
        }
    }
    getCurrentServer() {
        return this.currentServer;
    }
    addServer(u, implicit = false) {
        const urlParseFn = getUrlParseFn();
        u = urlParseFn ? urlParseFn(u) : u;
        const s = new ServerImpl(u, implicit);
        if (isIP(s.hostname)) {
            s.tlsName = this.tlsName;
        }
        this.servers.push(s);
    }
    selectServer() {
        if (this.firstSelect) {
            this.firstSelect = false;
            return this.currentServer;
        }
        const t = this.servers.shift();
        if (t) {
            this.servers.push(t);
            this.currentServer = t;
        }
        return t;
    }
    removeCurrentServer() {
        this.removeServer(this.currentServer);
    }
    removeServer(server) {
        if (server) {
            const index = this.servers.indexOf(server);
            this.servers.splice(index, 1);
        }
    }
    length() {
        return this.servers.length;
    }
    next() {
        return this.servers.length ? this.servers[0] : undefined;
    }
    getServers() {
        return this.servers;
    }
    update(info, encrypted) {
        const added = [];
        let deleted = [];
        const urlParseFn = getUrlParseFn();
        const discovered = new Map();
        if (info.connect_urls && info.connect_urls.length > 0) {
            info.connect_urls.forEach((hp)=>{
                hp = urlParseFn ? urlParseFn(hp, encrypted) : hp;
                const s = new ServerImpl(hp, true);
                discovered.set(hp, s);
            });
        }
        const toDelete = [];
        this.servers.forEach((s, index)=>{
            const u = s.listen;
            if (s.gossiped && this.currentServer.listen !== u && discovered.get(u) === undefined) {
                toDelete.push(index);
            }
            discovered.delete(u);
        });
        toDelete.reverse();
        toDelete.forEach((index)=>{
            const removed = this.servers.splice(index, 1);
            deleted = deleted.concat(removed[0].listen);
        });
        discovered.forEach((v, k)=>{
            this.servers.push(v);
            added.push(k);
        });
        return {
            added,
            deleted
        };
    }
}
class MuxSubscription {
    baseInbox;
    reqs;
    constructor(){
        this.reqs = new Map();
    }
    size() {
        return this.reqs.size;
    }
    init(prefix) {
        this.baseInbox = `${createInbox(prefix)}.`;
        return this.baseInbox;
    }
    add(r) {
        if (!isNaN(r.received)) {
            r.received = 0;
        }
        this.reqs.set(r.token, r);
    }
    get(token) {
        return this.reqs.get(token);
    }
    cancel(r) {
        this.reqs.delete(r.token);
    }
    getToken(m) {
        const s = m.subject || "";
        if (s.indexOf(this.baseInbox) === 0) {
            return s.substring(this.baseInbox.length);
        }
        return null;
    }
    all() {
        return Array.from(this.reqs.values());
    }
    handleError(isMuxPermissionError, err) {
        if (err && err.permissionContext) {
            if (isMuxPermissionError) {
                this.all().forEach((r)=>{
                    r.resolver(err, {});
                });
                return true;
            }
            const ctx = err.permissionContext;
            if (ctx.operation === "publish") {
                const req = this.all().find((s)=>{
                    return s.requestSubject === ctx.subject;
                });
                if (req) {
                    req.resolver(err, {});
                    return true;
                }
            }
        }
        return false;
    }
    dispatcher() {
        return (err, m)=>{
            const token = this.getToken(m);
            if (token) {
                const r = this.get(token);
                if (r) {
                    if (err === null && m.headers) {
                        err = isRequestError(m);
                    }
                    r.resolver(err, m);
                }
            }
        };
    }
    close() {
        const err = NatsError.errorForCode(ErrorCode.Timeout);
        this.reqs.forEach((req)=>{
            req.resolver(err, {});
        });
    }
}
class Heartbeat {
    ph;
    interval;
    maxOut;
    timer;
    pendings;
    constructor(ph, interval, maxOut){
        this.ph = ph;
        this.interval = interval;
        this.maxOut = maxOut;
        this.pendings = [];
    }
    start() {
        this.cancel();
        this._schedule();
    }
    cancel(stale) {
        if (this.timer) {
            clearTimeout(this.timer);
            this.timer = undefined;
        }
        this._reset();
        if (stale) {
            this.ph.disconnect();
        }
    }
    _schedule() {
        this.timer = setTimeout(()=>{
            this.ph.dispatchStatus({
                type: DebugEvents.PingTimer,
                data: `${this.pendings.length + 1}`
            });
            if (this.pendings.length === this.maxOut) {
                this.cancel(true);
                return;
            }
            const ping = deferred();
            this.ph.flush(ping).then(()=>{
                this._reset();
            }).catch(()=>{
                this.cancel();
            });
            this.pendings.push(ping);
            this._schedule();
        }, this.interval);
    }
    _reset() {
        this.pendings = this.pendings.filter((p)=>{
            const d = p;
            d.resolve();
            return false;
        });
    }
}
class AssertionError extends Error {
    constructor(msg){
        super(msg);
        this.name = "AssertionError";
    }
}
function assert(cond, msg = "Assertion failed.") {
    if (!cond) {
        throw new AssertionError(msg);
    }
}
const MIN_READ = 32 * 1024;
const MAX_SIZE = 2 ** 32 - 2;
function copy(src, dst, off = 0) {
    const r = dst.byteLength - off;
    if (src.byteLength > r) {
        src = src.subarray(0, r);
    }
    dst.set(src, off);
    return src.byteLength;
}
class DenoBuffer {
    _buf;
    _off;
    constructor(ab){
        this._off = 0;
        if (ab == null) {
            this._buf = new Uint8Array(0);
            return;
        }
        this._buf = new Uint8Array(ab);
    }
    bytes(options = {
        copy: true
    }) {
        if (options.copy === false) return this._buf.subarray(this._off);
        return this._buf.slice(this._off);
    }
    empty() {
        return this._buf.byteLength <= this._off;
    }
    get length() {
        return this._buf.byteLength - this._off;
    }
    get capacity() {
        return this._buf.buffer.byteLength;
    }
    truncate(n) {
        if (n === 0) {
            this.reset();
            return;
        }
        if (n < 0 || n > this.length) {
            throw Error("bytes.Buffer: truncation out of range");
        }
        this._reslice(this._off + n);
    }
    reset() {
        this._reslice(0);
        this._off = 0;
    }
    _tryGrowByReslice(n) {
        const l = this._buf.byteLength;
        if (n <= this.capacity - l) {
            this._reslice(l + n);
            return l;
        }
        return -1;
    }
    _reslice(len) {
        assert(len <= this._buf.buffer.byteLength);
        this._buf = new Uint8Array(this._buf.buffer, 0, len);
    }
    readByte() {
        const a = new Uint8Array(1);
        if (this.read(a)) {
            return a[0];
        }
        return null;
    }
    read(p) {
        if (this.empty()) {
            this.reset();
            if (p.byteLength === 0) {
                return 0;
            }
            return null;
        }
        const nread = copy(this._buf.subarray(this._off), p);
        this._off += nread;
        return nread;
    }
    writeByte(n) {
        return this.write(Uint8Array.of(n));
    }
    writeString(s) {
        return this.write(TE.encode(s));
    }
    write(p) {
        const m = this._grow(p.byteLength);
        return copy(p, this._buf, m);
    }
    _grow(n) {
        const m = this.length;
        if (m === 0 && this._off !== 0) {
            this.reset();
        }
        const i = this._tryGrowByReslice(n);
        if (i >= 0) {
            return i;
        }
        const c = this.capacity;
        if (n <= Math.floor(c / 2) - m) {
            copy(this._buf.subarray(this._off), this._buf);
        } else if (c + n > MAX_SIZE) {
            throw new Error("The buffer cannot be grown beyond the maximum size.");
        } else {
            const buf = new Uint8Array(Math.min(2 * c + n, MAX_SIZE));
            copy(this._buf.subarray(this._off), buf);
            this._buf = buf;
        }
        this._off = 0;
        this._reslice(Math.min(m + n, MAX_SIZE));
        return m;
    }
    grow(n) {
        if (n < 0) {
            throw Error("Buffer._grow: negative count");
        }
        const m = this._grow(n);
        this._reslice(m);
    }
    readFrom(r) {
        let n = 0;
        const tmp = new Uint8Array(MIN_READ);
        while(true){
            const shouldGrow = this.capacity - this.length < MIN_READ;
            const buf = shouldGrow ? tmp : new Uint8Array(this._buf.buffer, this.length);
            const nread = r.read(buf);
            if (nread === null) {
                return n;
            }
            if (shouldGrow) this.write(buf.subarray(0, nread));
            else this._reslice(this.length + nread);
            n += nread;
        }
    }
}
var Kind;
(function(Kind) {
    Kind[Kind["OK"] = 0] = "OK";
    Kind[Kind["ERR"] = 1] = "ERR";
    Kind[Kind["MSG"] = 2] = "MSG";
    Kind[Kind["INFO"] = 3] = "INFO";
    Kind[Kind["PING"] = 4] = "PING";
    Kind[Kind["PONG"] = 5] = "PONG";
})(Kind || (Kind = {}));
function newMsgArg() {
    const ma = {};
    ma.sid = -1;
    ma.hdr = -1;
    ma.size = -1;
    return ma;
}
const ASCII_0 = 48;
class Parser {
    dispatcher;
    state;
    as;
    drop;
    hdr;
    ma;
    argBuf;
    msgBuf;
    constructor(dispatcher){
        this.dispatcher = dispatcher;
        this.state = State.OP_START;
        this.as = 0;
        this.drop = 0;
        this.hdr = 0;
    }
    parse(buf) {
        let i;
        for(i = 0; i < buf.length; i++){
            const b = buf[i];
            switch(this.state){
                case State.OP_START:
                    switch(b){
                        case cc.M:
                        case cc.m:
                            this.state = State.OP_M;
                            this.hdr = -1;
                            this.ma = newMsgArg();
                            break;
                        case cc.H:
                        case cc.h:
                            this.state = State.OP_H;
                            this.hdr = 0;
                            this.ma = newMsgArg();
                            break;
                        case cc.P:
                        case cc.p:
                            this.state = State.OP_P;
                            break;
                        case cc.PLUS:
                            this.state = State.OP_PLUS;
                            break;
                        case cc.MINUS:
                            this.state = State.OP_MINUS;
                            break;
                        case cc.I:
                        case cc.i:
                            this.state = State.OP_I;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_H:
                    switch(b){
                        case cc.M:
                        case cc.m:
                            this.state = State.OP_M;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_M:
                    switch(b){
                        case cc.S:
                        case cc.s:
                            this.state = State.OP_MS;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_MS:
                    switch(b){
                        case cc.G:
                        case cc.g:
                            this.state = State.OP_MSG;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_MSG:
                    switch(b){
                        case cc.SPACE:
                        case cc.TAB:
                            this.state = State.OP_MSG_SPC;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_MSG_SPC:
                    switch(b){
                        case cc.SPACE:
                        case cc.TAB:
                            continue;
                        default:
                            this.state = State.MSG_ARG;
                            this.as = i;
                    }
                    break;
                case State.MSG_ARG:
                    switch(b){
                        case cc.CR:
                            this.drop = 1;
                            break;
                        case cc.NL:
                            {
                                const arg = this.argBuf ? this.argBuf.bytes() : buf.subarray(this.as, i - this.drop);
                                this.processMsgArgs(arg);
                                this.drop = 0;
                                this.as = i + 1;
                                this.state = State.MSG_PAYLOAD;
                                i = this.as + this.ma.size - 1;
                                break;
                            }
                        default:
                            if (this.argBuf) {
                                this.argBuf.writeByte(b);
                            }
                    }
                    break;
                case State.MSG_PAYLOAD:
                    if (this.msgBuf) {
                        if (this.msgBuf.length >= this.ma.size) {
                            const data = this.msgBuf.bytes({
                                copy: false
                            });
                            this.dispatcher.push({
                                kind: Kind.MSG,
                                msg: this.ma,
                                data: data
                            });
                            this.argBuf = undefined;
                            this.msgBuf = undefined;
                            this.state = State.MSG_END;
                        } else {
                            let toCopy = this.ma.size - this.msgBuf.length;
                            const avail = buf.length - i;
                            if (avail < toCopy) {
                                toCopy = avail;
                            }
                            if (toCopy > 0) {
                                this.msgBuf.write(buf.subarray(i, i + toCopy));
                                i = i + toCopy - 1;
                            } else {
                                this.msgBuf.writeByte(b);
                            }
                        }
                    } else if (i - this.as >= this.ma.size) {
                        this.dispatcher.push({
                            kind: Kind.MSG,
                            msg: this.ma,
                            data: buf.subarray(this.as, i)
                        });
                        this.argBuf = undefined;
                        this.msgBuf = undefined;
                        this.state = State.MSG_END;
                    }
                    break;
                case State.MSG_END:
                    switch(b){
                        case cc.NL:
                            this.drop = 0;
                            this.as = i + 1;
                            this.state = State.OP_START;
                            break;
                        default:
                            continue;
                    }
                    break;
                case State.OP_PLUS:
                    switch(b){
                        case cc.O:
                        case cc.o:
                            this.state = State.OP_PLUS_O;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_PLUS_O:
                    switch(b){
                        case cc.K:
                        case cc.k:
                            this.state = State.OP_PLUS_OK;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_PLUS_OK:
                    switch(b){
                        case cc.NL:
                            this.dispatcher.push({
                                kind: Kind.OK
                            });
                            this.drop = 0;
                            this.state = State.OP_START;
                            break;
                    }
                    break;
                case State.OP_MINUS:
                    switch(b){
                        case cc.E:
                        case cc.e:
                            this.state = State.OP_MINUS_E;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_MINUS_E:
                    switch(b){
                        case cc.R:
                        case cc.r:
                            this.state = State.OP_MINUS_ER;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_MINUS_ER:
                    switch(b){
                        case cc.R:
                        case cc.r:
                            this.state = State.OP_MINUS_ERR;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_MINUS_ERR:
                    switch(b){
                        case cc.SPACE:
                        case cc.TAB:
                            this.state = State.OP_MINUS_ERR_SPC;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_MINUS_ERR_SPC:
                    switch(b){
                        case cc.SPACE:
                        case cc.TAB:
                            continue;
                        default:
                            this.state = State.MINUS_ERR_ARG;
                            this.as = i;
                    }
                    break;
                case State.MINUS_ERR_ARG:
                    switch(b){
                        case cc.CR:
                            this.drop = 1;
                            break;
                        case cc.NL:
                            {
                                let arg;
                                if (this.argBuf) {
                                    arg = this.argBuf.bytes();
                                    this.argBuf = undefined;
                                } else {
                                    arg = buf.subarray(this.as, i - this.drop);
                                }
                                this.dispatcher.push({
                                    kind: Kind.ERR,
                                    data: arg
                                });
                                this.drop = 0;
                                this.as = i + 1;
                                this.state = State.OP_START;
                                break;
                            }
                        default:
                            if (this.argBuf) {
                                this.argBuf.write(Uint8Array.of(b));
                            }
                    }
                    break;
                case State.OP_P:
                    switch(b){
                        case cc.I:
                        case cc.i:
                            this.state = State.OP_PI;
                            break;
                        case cc.O:
                        case cc.o:
                            this.state = State.OP_PO;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_PO:
                    switch(b){
                        case cc.N:
                        case cc.n:
                            this.state = State.OP_PON;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_PON:
                    switch(b){
                        case cc.G:
                        case cc.g:
                            this.state = State.OP_PONG;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_PONG:
                    switch(b){
                        case cc.NL:
                            this.dispatcher.push({
                                kind: Kind.PONG
                            });
                            this.drop = 0;
                            this.state = State.OP_START;
                            break;
                    }
                    break;
                case State.OP_PI:
                    switch(b){
                        case cc.N:
                        case cc.n:
                            this.state = State.OP_PIN;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_PIN:
                    switch(b){
                        case cc.G:
                        case cc.g:
                            this.state = State.OP_PING;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_PING:
                    switch(b){
                        case cc.NL:
                            this.dispatcher.push({
                                kind: Kind.PING
                            });
                            this.drop = 0;
                            this.state = State.OP_START;
                            break;
                    }
                    break;
                case State.OP_I:
                    switch(b){
                        case cc.N:
                        case cc.n:
                            this.state = State.OP_IN;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_IN:
                    switch(b){
                        case cc.F:
                        case cc.f:
                            this.state = State.OP_INF;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_INF:
                    switch(b){
                        case cc.O:
                        case cc.o:
                            this.state = State.OP_INFO;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_INFO:
                    switch(b){
                        case cc.SPACE:
                        case cc.TAB:
                            this.state = State.OP_INFO_SPC;
                            break;
                        default:
                            throw this.fail(buf.subarray(i));
                    }
                    break;
                case State.OP_INFO_SPC:
                    switch(b){
                        case cc.SPACE:
                        case cc.TAB:
                            continue;
                        default:
                            this.state = State.INFO_ARG;
                            this.as = i;
                    }
                    break;
                case State.INFO_ARG:
                    switch(b){
                        case cc.CR:
                            this.drop = 1;
                            break;
                        case cc.NL:
                            {
                                let arg;
                                if (this.argBuf) {
                                    arg = this.argBuf.bytes();
                                    this.argBuf = undefined;
                                } else {
                                    arg = buf.subarray(this.as, i - this.drop);
                                }
                                this.dispatcher.push({
                                    kind: Kind.INFO,
                                    data: arg
                                });
                                this.drop = 0;
                                this.as = i + 1;
                                this.state = State.OP_START;
                                break;
                            }
                        default:
                            if (this.argBuf) {
                                this.argBuf.writeByte(b);
                            }
                    }
                    break;
                default:
                    throw this.fail(buf.subarray(i));
            }
        }
        if ((this.state === State.MSG_ARG || this.state === State.MINUS_ERR_ARG || this.state === State.INFO_ARG) && !this.argBuf) {
            this.argBuf = new DenoBuffer(buf.subarray(this.as, i - this.drop));
        }
        if (this.state === State.MSG_PAYLOAD && !this.msgBuf) {
            if (!this.argBuf) {
                this.cloneMsgArg();
            }
            this.msgBuf = new DenoBuffer(buf.subarray(this.as));
        }
    }
    cloneMsgArg() {
        const s = this.ma.subject.length;
        const r = this.ma.reply ? this.ma.reply.length : 0;
        const buf = new Uint8Array(s + r);
        buf.set(this.ma.subject);
        if (this.ma.reply) {
            buf.set(this.ma.reply, s);
        }
        this.argBuf = new DenoBuffer(buf);
        this.ma.subject = buf.subarray(0, s);
        if (this.ma.reply) {
            this.ma.reply = buf.subarray(s);
        }
    }
    processMsgArgs(arg) {
        if (this.hdr >= 0) {
            return this.processHeaderMsgArgs(arg);
        }
        const args = [];
        let start = -1;
        for(let i = 0; i < arg.length; i++){
            const b = arg[i];
            switch(b){
                case cc.SPACE:
                case cc.TAB:
                case cc.CR:
                case cc.NL:
                    if (start >= 0) {
                        args.push(arg.subarray(start, i));
                        start = -1;
                    }
                    break;
                default:
                    if (start < 0) {
                        start = i;
                    }
            }
        }
        if (start >= 0) {
            args.push(arg.subarray(start));
        }
        switch(args.length){
            case 3:
                this.ma.subject = args[0];
                this.ma.sid = this.protoParseInt(args[1]);
                this.ma.reply = undefined;
                this.ma.size = this.protoParseInt(args[2]);
                break;
            case 4:
                this.ma.subject = args[0];
                this.ma.sid = this.protoParseInt(args[1]);
                this.ma.reply = args[2];
                this.ma.size = this.protoParseInt(args[3]);
                break;
            default:
                throw this.fail(arg, "processMsgArgs Parse Error");
        }
        if (this.ma.sid < 0) {
            throw this.fail(arg, "processMsgArgs Bad or Missing Sid Error");
        }
        if (this.ma.size < 0) {
            throw this.fail(arg, "processMsgArgs Bad or Missing Size Error");
        }
    }
    fail(data, label = "") {
        if (!label) {
            label = `parse error [${this.state}]`;
        } else {
            label = `${label} [${this.state}]`;
        }
        return new Error(`${label}: ${TD.decode(data)}`);
    }
    processHeaderMsgArgs(arg) {
        const args = [];
        let start = -1;
        for(let i = 0; i < arg.length; i++){
            const b = arg[i];
            switch(b){
                case cc.SPACE:
                case cc.TAB:
                case cc.CR:
                case cc.NL:
                    if (start >= 0) {
                        args.push(arg.subarray(start, i));
                        start = -1;
                    }
                    break;
                default:
                    if (start < 0) {
                        start = i;
                    }
            }
        }
        if (start >= 0) {
            args.push(arg.subarray(start));
        }
        switch(args.length){
            case 4:
                this.ma.subject = args[0];
                this.ma.sid = this.protoParseInt(args[1]);
                this.ma.reply = undefined;
                this.ma.hdr = this.protoParseInt(args[2]);
                this.ma.size = this.protoParseInt(args[3]);
                break;
            case 5:
                this.ma.subject = args[0];
                this.ma.sid = this.protoParseInt(args[1]);
                this.ma.reply = args[2];
                this.ma.hdr = this.protoParseInt(args[3]);
                this.ma.size = this.protoParseInt(args[4]);
                break;
            default:
                throw this.fail(arg, "processHeaderMsgArgs Parse Error");
        }
        if (this.ma.sid < 0) {
            throw this.fail(arg, "processHeaderMsgArgs Bad or Missing Sid Error");
        }
        if (this.ma.hdr < 0 || this.ma.hdr > this.ma.size) {
            throw this.fail(arg, "processHeaderMsgArgs Bad or Missing Header Size Error");
        }
        if (this.ma.size < 0) {
            throw this.fail(arg, "processHeaderMsgArgs Bad or Missing Size Error");
        }
    }
    protoParseInt(a) {
        if (a.length === 0) {
            return -1;
        }
        let n = 0;
        for(let i = 0; i < a.length; i++){
            if (a[i] < 48 || a[i] > 57) {
                return -1;
            }
            n = n * 10 + (a[i] - ASCII_0);
        }
        return n;
    }
}
var State;
(function(State) {
    State[State["OP_START"] = 0] = "OP_START";
    State[State["OP_PLUS"] = 1] = "OP_PLUS";
    State[State["OP_PLUS_O"] = 2] = "OP_PLUS_O";
    State[State["OP_PLUS_OK"] = 3] = "OP_PLUS_OK";
    State[State["OP_MINUS"] = 4] = "OP_MINUS";
    State[State["OP_MINUS_E"] = 5] = "OP_MINUS_E";
    State[State["OP_MINUS_ER"] = 6] = "OP_MINUS_ER";
    State[State["OP_MINUS_ERR"] = 7] = "OP_MINUS_ERR";
    State[State["OP_MINUS_ERR_SPC"] = 8] = "OP_MINUS_ERR_SPC";
    State[State["MINUS_ERR_ARG"] = 9] = "MINUS_ERR_ARG";
    State[State["OP_M"] = 10] = "OP_M";
    State[State["OP_MS"] = 11] = "OP_MS";
    State[State["OP_MSG"] = 12] = "OP_MSG";
    State[State["OP_MSG_SPC"] = 13] = "OP_MSG_SPC";
    State[State["MSG_ARG"] = 14] = "MSG_ARG";
    State[State["MSG_PAYLOAD"] = 15] = "MSG_PAYLOAD";
    State[State["MSG_END"] = 16] = "MSG_END";
    State[State["OP_H"] = 17] = "OP_H";
    State[State["OP_P"] = 18] = "OP_P";
    State[State["OP_PI"] = 19] = "OP_PI";
    State[State["OP_PIN"] = 20] = "OP_PIN";
    State[State["OP_PING"] = 21] = "OP_PING";
    State[State["OP_PO"] = 22] = "OP_PO";
    State[State["OP_PON"] = 23] = "OP_PON";
    State[State["OP_PONG"] = 24] = "OP_PONG";
    State[State["OP_I"] = 25] = "OP_I";
    State[State["OP_IN"] = 26] = "OP_IN";
    State[State["OP_INF"] = 27] = "OP_INF";
    State[State["OP_INFO"] = 28] = "OP_INFO";
    State[State["OP_INFO_SPC"] = 29] = "OP_INFO_SPC";
    State[State["INFO_ARG"] = 30] = "INFO_ARG";
})(State || (State = {}));
var cc;
(function(cc) {
    cc[cc["CR"] = "\r".charCodeAt(0)] = "CR";
    cc[cc["E"] = "E".charCodeAt(0)] = "E";
    cc[cc["e"] = "e".charCodeAt(0)] = "e";
    cc[cc["F"] = "F".charCodeAt(0)] = "F";
    cc[cc["f"] = "f".charCodeAt(0)] = "f";
    cc[cc["G"] = "G".charCodeAt(0)] = "G";
    cc[cc["g"] = "g".charCodeAt(0)] = "g";
    cc[cc["H"] = "H".charCodeAt(0)] = "H";
    cc[cc["h"] = "h".charCodeAt(0)] = "h";
    cc[cc["I"] = "I".charCodeAt(0)] = "I";
    cc[cc["i"] = "i".charCodeAt(0)] = "i";
    cc[cc["K"] = "K".charCodeAt(0)] = "K";
    cc[cc["k"] = "k".charCodeAt(0)] = "k";
    cc[cc["M"] = "M".charCodeAt(0)] = "M";
    cc[cc["m"] = "m".charCodeAt(0)] = "m";
    cc[cc["MINUS"] = "-".charCodeAt(0)] = "MINUS";
    cc[cc["N"] = "N".charCodeAt(0)] = "N";
    cc[cc["n"] = "n".charCodeAt(0)] = "n";
    cc[cc["NL"] = "\n".charCodeAt(0)] = "NL";
    cc[cc["O"] = "O".charCodeAt(0)] = "O";
    cc[cc["o"] = "o".charCodeAt(0)] = "o";
    cc[cc["P"] = "P".charCodeAt(0)] = "P";
    cc[cc["p"] = "p".charCodeAt(0)] = "p";
    cc[cc["PLUS"] = "+".charCodeAt(0)] = "PLUS";
    cc[cc["R"] = "R".charCodeAt(0)] = "R";
    cc[cc["r"] = "r".charCodeAt(0)] = "r";
    cc[cc["S"] = "S".charCodeAt(0)] = "S";
    cc[cc["s"] = "s".charCodeAt(0)] = "s";
    cc[cc["SPACE"] = " ".charCodeAt(0)] = "SPACE";
    cc[cc["TAB"] = "\t".charCodeAt(0)] = "TAB";
})(cc || (cc = {}));
(function(nacl) {
    'use strict';
    var u64 = function(h, l) {
        this.hi = h | 0 >>> 0;
        this.lo = l | 0 >>> 0;
    };
    var gf = function(init) {
        var i, r = new Float64Array(16);
        if (init) for(i = 0; i < init.length; i++)r[i] = init[i];
        return r;
    };
    var randombytes = function() {
        throw new Error('no PRNG');
    };
    var _0 = new Uint8Array(16);
    var _9 = new Uint8Array(32);
    _9[0] = 9;
    var gf0 = gf(), gf1 = gf([
        1
    ]), _121665 = gf([
        0xdb41,
        1
    ]), D = gf([
        0x78a3,
        0x1359,
        0x4dca,
        0x75eb,
        0xd8ab,
        0x4141,
        0x0a4d,
        0x0070,
        0xe898,
        0x7779,
        0x4079,
        0x8cc7,
        0xfe73,
        0x2b6f,
        0x6cee,
        0x5203
    ]), D2 = gf([
        0xf159,
        0x26b2,
        0x9b94,
        0xebd6,
        0xb156,
        0x8283,
        0x149a,
        0x00e0,
        0xd130,
        0xeef3,
        0x80f2,
        0x198e,
        0xfce7,
        0x56df,
        0xd9dc,
        0x2406
    ]), X = gf([
        0xd51a,
        0x8f25,
        0x2d60,
        0xc956,
        0xa7b2,
        0x9525,
        0xc760,
        0x692c,
        0xdc5c,
        0xfdd6,
        0xe231,
        0xc0a4,
        0x53fe,
        0xcd6e,
        0x36d3,
        0x2169
    ]), Y = gf([
        0x6658,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666,
        0x6666
    ]), I = gf([
        0xa0b0,
        0x4a0e,
        0x1b27,
        0xc4ee,
        0xe478,
        0xad2f,
        0x1806,
        0x2f43,
        0xd7a7,
        0x3dfb,
        0x0099,
        0x2b4d,
        0xdf0b,
        0x4fc1,
        0x2480,
        0x2b83
    ]);
    function L32(x, c) {
        return x << c | x >>> 32 - c;
    }
    function ld32(x, i) {
        var u = x[i + 3] & 0xff;
        u = u << 8 | x[i + 2] & 0xff;
        u = u << 8 | x[i + 1] & 0xff;
        return u << 8 | x[i + 0] & 0xff;
    }
    function dl64(x, i) {
        var h = x[i] << 24 | x[i + 1] << 16 | x[i + 2] << 8 | x[i + 3];
        var l = x[i + 4] << 24 | x[i + 5] << 16 | x[i + 6] << 8 | x[i + 7];
        return new u64(h, l);
    }
    function st32(x, j, u) {
        var i;
        for(i = 0; i < 4; i++){
            x[j + i] = u & 255;
            u >>>= 8;
        }
    }
    function ts64(x, i, u) {
        x[i] = u.hi >> 24 & 0xff;
        x[i + 1] = u.hi >> 16 & 0xff;
        x[i + 2] = u.hi >> 8 & 0xff;
        x[i + 3] = u.hi & 0xff;
        x[i + 4] = u.lo >> 24 & 0xff;
        x[i + 5] = u.lo >> 16 & 0xff;
        x[i + 6] = u.lo >> 8 & 0xff;
        x[i + 7] = u.lo & 0xff;
    }
    function vn(x, xi, y, yi, n) {
        var i, d = 0;
        for(i = 0; i < n; i++)d |= x[xi + i] ^ y[yi + i];
        return (1 & d - 1 >>> 8) - 1;
    }
    function crypto_verify_16(x, xi, y, yi) {
        return vn(x, xi, y, yi, 16);
    }
    function crypto_verify_32(x, xi, y, yi) {
        return vn(x, xi, y, yi, 32);
    }
    function core(out, inp, k, c, h) {
        var w = new Uint32Array(16), x = new Uint32Array(16), y = new Uint32Array(16), t = new Uint32Array(4);
        var i, j, m;
        for(i = 0; i < 4; i++){
            x[5 * i] = ld32(c, 4 * i);
            x[1 + i] = ld32(k, 4 * i);
            x[6 + i] = ld32(inp, 4 * i);
            x[11 + i] = ld32(k, 16 + 4 * i);
        }
        for(i = 0; i < 16; i++)y[i] = x[i];
        for(i = 0; i < 20; i++){
            for(j = 0; j < 4; j++){
                for(m = 0; m < 4; m++)t[m] = x[(5 * j + 4 * m) % 16];
                t[1] ^= L32(t[0] + t[3] | 0, 7);
                t[2] ^= L32(t[1] + t[0] | 0, 9);
                t[3] ^= L32(t[2] + t[1] | 0, 13);
                t[0] ^= L32(t[3] + t[2] | 0, 18);
                for(m = 0; m < 4; m++)w[4 * j + (j + m) % 4] = t[m];
            }
            for(m = 0; m < 16; m++)x[m] = w[m];
        }
        if (h) {
            for(i = 0; i < 16; i++)x[i] = x[i] + y[i] | 0;
            for(i = 0; i < 4; i++){
                x[5 * i] = x[5 * i] - ld32(c, 4 * i) | 0;
                x[6 + i] = x[6 + i] - ld32(inp, 4 * i) | 0;
            }
            for(i = 0; i < 4; i++){
                st32(out, 4 * i, x[5 * i]);
                st32(out, 16 + 4 * i, x[6 + i]);
            }
        } else {
            for(i = 0; i < 16; i++)st32(out, 4 * i, x[i] + y[i] | 0);
        }
    }
    function crypto_core_salsa20(out, inp, k, c) {
        core(out, inp, k, c, false);
        return 0;
    }
    function crypto_core_hsalsa20(out, inp, k, c) {
        core(out, inp, k, c, true);
        return 0;
    }
    var sigma = new Uint8Array([
        101,
        120,
        112,
        97,
        110,
        100,
        32,
        51,
        50,
        45,
        98,
        121,
        116,
        101,
        32,
        107
    ]);
    function crypto_stream_salsa20_xor(c, cpos, m, mpos, b, n, k) {
        var z = new Uint8Array(16), x = new Uint8Array(64);
        var u, i;
        if (!b) return 0;
        for(i = 0; i < 16; i++)z[i] = 0;
        for(i = 0; i < 8; i++)z[i] = n[i];
        while(b >= 64){
            crypto_core_salsa20(x, z, k, sigma);
            for(i = 0; i < 64; i++)c[cpos + i] = (m ? m[mpos + i] : 0) ^ x[i];
            u = 1;
            for(i = 8; i < 16; i++){
                u = u + (z[i] & 0xff) | 0;
                z[i] = u & 0xff;
                u >>>= 8;
            }
            b -= 64;
            cpos += 64;
            if (m) mpos += 64;
        }
        if (b > 0) {
            crypto_core_salsa20(x, z, k, sigma);
            for(i = 0; i < b; i++)c[cpos + i] = (m ? m[mpos + i] : 0) ^ x[i];
        }
        return 0;
    }
    function crypto_stream_salsa20(c, cpos, d, n, k) {
        return crypto_stream_salsa20_xor(c, cpos, null, 0, d, n, k);
    }
    function crypto_stream(c, cpos, d, n, k) {
        var s = new Uint8Array(32);
        crypto_core_hsalsa20(s, n, k, sigma);
        return crypto_stream_salsa20(c, cpos, d, n.subarray(16), s);
    }
    function crypto_stream_xor(c, cpos, m, mpos, d, n, k) {
        var s = new Uint8Array(32);
        crypto_core_hsalsa20(s, n, k, sigma);
        return crypto_stream_salsa20_xor(c, cpos, m, mpos, d, n.subarray(16), s);
    }
    function add1305(h, c) {
        var j, u = 0;
        for(j = 0; j < 17; j++){
            u = u + (h[j] + c[j] | 0) | 0;
            h[j] = u & 255;
            u >>>= 8;
        }
    }
    var minusp = new Uint32Array([
        5,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        252
    ]);
    function crypto_onetimeauth(out, outpos, m, mpos, n, k) {
        var s, i, j, u;
        var x = new Uint32Array(17), r = new Uint32Array(17), h = new Uint32Array(17), c = new Uint32Array(17), g = new Uint32Array(17);
        for(j = 0; j < 17; j++)r[j] = h[j] = 0;
        for(j = 0; j < 16; j++)r[j] = k[j];
        r[3] &= 15;
        r[4] &= 252;
        r[7] &= 15;
        r[8] &= 252;
        r[11] &= 15;
        r[12] &= 252;
        r[15] &= 15;
        while(n > 0){
            for(j = 0; j < 17; j++)c[j] = 0;
            for(j = 0; j < 16 && j < n; ++j)c[j] = m[mpos + j];
            c[j] = 1;
            mpos += j;
            n -= j;
            add1305(h, c);
            for(i = 0; i < 17; i++){
                x[i] = 0;
                for(j = 0; j < 17; j++)x[i] = x[i] + h[j] * (j <= i ? r[i - j] : 320 * r[i + 17 - j] | 0) | 0 | 0;
            }
            for(i = 0; i < 17; i++)h[i] = x[i];
            u = 0;
            for(j = 0; j < 16; j++){
                u = u + h[j] | 0;
                h[j] = u & 255;
                u >>>= 8;
            }
            u = u + h[16] | 0;
            h[16] = u & 3;
            u = 5 * (u >>> 2) | 0;
            for(j = 0; j < 16; j++){
                u = u + h[j] | 0;
                h[j] = u & 255;
                u >>>= 8;
            }
            u = u + h[16] | 0;
            h[16] = u;
        }
        for(j = 0; j < 17; j++)g[j] = h[j];
        add1305(h, minusp);
        s = -(h[16] >>> 7) | 0;
        for(j = 0; j < 17; j++)h[j] ^= s & (g[j] ^ h[j]);
        for(j = 0; j < 16; j++)c[j] = k[j + 16];
        c[16] = 0;
        add1305(h, c);
        for(j = 0; j < 16; j++)out[outpos + j] = h[j];
        return 0;
    }
    function crypto_onetimeauth_verify(h, hpos, m, mpos, n, k) {
        var x = new Uint8Array(16);
        crypto_onetimeauth(x, 0, m, mpos, n, k);
        return crypto_verify_16(h, hpos, x, 0);
    }
    function crypto_secretbox(c, m, d, n, k) {
        var i;
        if (d < 32) return -1;
        crypto_stream_xor(c, 0, m, 0, d, n, k);
        crypto_onetimeauth(c, 16, c, 32, d - 32, c);
        for(i = 0; i < 16; i++)c[i] = 0;
        return 0;
    }
    function crypto_secretbox_open(m, c, d, n, k) {
        var i;
        var x = new Uint8Array(32);
        if (d < 32) return -1;
        crypto_stream(x, 0, 32, n, k);
        if (crypto_onetimeauth_verify(c, 16, c, 32, d - 32, x) !== 0) return -1;
        crypto_stream_xor(m, 0, c, 0, d, n, k);
        for(i = 0; i < 32; i++)m[i] = 0;
        return 0;
    }
    function set25519(r, a) {
        var i;
        for(i = 0; i < 16; i++)r[i] = a[i] | 0;
    }
    function car25519(o) {
        var c;
        var i;
        for(i = 0; i < 16; i++){
            o[i] += 65536;
            c = Math.floor(o[i] / 65536);
            o[(i + 1) * (i < 15 ? 1 : 0)] += c - 1 + 37 * (c - 1) * (i === 15 ? 1 : 0);
            o[i] -= c * 65536;
        }
    }
    function sel25519(p, q, b) {
        var t, c = ~(b - 1);
        for(var i = 0; i < 16; i++){
            t = c & (p[i] ^ q[i]);
            p[i] ^= t;
            q[i] ^= t;
        }
    }
    function pack25519(o, n) {
        var i, j, b;
        var m = gf(), t = gf();
        for(i = 0; i < 16; i++)t[i] = n[i];
        car25519(t);
        car25519(t);
        car25519(t);
        for(j = 0; j < 2; j++){
            m[0] = t[0] - 0xffed;
            for(i = 1; i < 15; i++){
                m[i] = t[i] - 0xffff - (m[i - 1] >> 16 & 1);
                m[i - 1] &= 0xffff;
            }
            m[15] = t[15] - 0x7fff - (m[14] >> 16 & 1);
            b = m[15] >> 16 & 1;
            m[14] &= 0xffff;
            sel25519(t, m, 1 - b);
        }
        for(i = 0; i < 16; i++){
            o[2 * i] = t[i] & 0xff;
            o[2 * i + 1] = t[i] >> 8;
        }
    }
    function neq25519(a, b) {
        var c = new Uint8Array(32), d = new Uint8Array(32);
        pack25519(c, a);
        pack25519(d, b);
        return crypto_verify_32(c, 0, d, 0);
    }
    function par25519(a) {
        var d = new Uint8Array(32);
        pack25519(d, a);
        return d[0] & 1;
    }
    function unpack25519(o, n) {
        var i;
        for(i = 0; i < 16; i++)o[i] = n[2 * i] + (n[2 * i + 1] << 8);
        o[15] &= 0x7fff;
    }
    function A(o, a, b) {
        var i;
        for(i = 0; i < 16; i++)o[i] = a[i] + b[i] | 0;
    }
    function Z(o, a, b) {
        var i;
        for(i = 0; i < 16; i++)o[i] = a[i] - b[i] | 0;
    }
    function M(o, a, b) {
        var i, j, t = new Float64Array(31);
        for(i = 0; i < 31; i++)t[i] = 0;
        for(i = 0; i < 16; i++){
            for(j = 0; j < 16; j++){
                t[i + j] += a[i] * b[j];
            }
        }
        for(i = 0; i < 15; i++){
            t[i] += 38 * t[i + 16];
        }
        for(i = 0; i < 16; i++)o[i] = t[i];
        car25519(o);
        car25519(o);
    }
    function S(o, a) {
        M(o, a, a);
    }
    function inv25519(o, i) {
        var c = gf();
        var a;
        for(a = 0; a < 16; a++)c[a] = i[a];
        for(a = 253; a >= 0; a--){
            S(c, c);
            if (a !== 2 && a !== 4) M(c, c, i);
        }
        for(a = 0; a < 16; a++)o[a] = c[a];
    }
    function pow2523(o, i) {
        var c = gf();
        var a;
        for(a = 0; a < 16; a++)c[a] = i[a];
        for(a = 250; a >= 0; a--){
            S(c, c);
            if (a !== 1) M(c, c, i);
        }
        for(a = 0; a < 16; a++)o[a] = c[a];
    }
    function crypto_scalarmult(q, n, p) {
        var z = new Uint8Array(32);
        var x = new Float64Array(80), r, i;
        var a = gf(), b = gf(), c = gf(), d = gf(), e = gf(), f = gf();
        for(i = 0; i < 31; i++)z[i] = n[i];
        z[31] = n[31] & 127 | 64;
        z[0] &= 248;
        unpack25519(x, p);
        for(i = 0; i < 16; i++){
            b[i] = x[i];
            d[i] = a[i] = c[i] = 0;
        }
        a[0] = d[0] = 1;
        for(i = 254; i >= 0; --i){
            r = z[i >>> 3] >>> (i & 7) & 1;
            sel25519(a, b, r);
            sel25519(c, d, r);
            A(e, a, c);
            Z(a, a, c);
            A(c, b, d);
            Z(b, b, d);
            S(d, e);
            S(f, a);
            M(a, c, a);
            M(c, b, e);
            A(e, a, c);
            Z(a, a, c);
            S(b, a);
            Z(c, d, f);
            M(a, c, _121665);
            A(a, a, d);
            M(c, c, a);
            M(a, d, f);
            M(d, b, x);
            S(b, e);
            sel25519(a, b, r);
            sel25519(c, d, r);
        }
        for(i = 0; i < 16; i++){
            x[i + 16] = a[i];
            x[i + 32] = c[i];
            x[i + 48] = b[i];
            x[i + 64] = d[i];
        }
        var x32 = x.subarray(32);
        var x16 = x.subarray(16);
        inv25519(x32, x32);
        M(x16, x16, x32);
        pack25519(q, x16);
        return 0;
    }
    function crypto_scalarmult_base(q, n) {
        return crypto_scalarmult(q, n, _9);
    }
    function crypto_box_keypair(y, x) {
        randombytes(x, 32);
        return crypto_scalarmult_base(y, x);
    }
    function crypto_box_beforenm(k, y, x) {
        var s = new Uint8Array(32);
        crypto_scalarmult(s, x, y);
        return crypto_core_hsalsa20(k, _0, s, sigma);
    }
    var crypto_box_afternm = crypto_secretbox;
    var crypto_box_open_afternm = crypto_secretbox_open;
    function crypto_box(c, m, d, n, y, x) {
        var k = new Uint8Array(32);
        crypto_box_beforenm(k, y, x);
        return crypto_box_afternm(c, m, d, n, k);
    }
    function crypto_box_open(m, c, d, n, y, x) {
        var k = new Uint8Array(32);
        crypto_box_beforenm(k, y, x);
        return crypto_box_open_afternm(m, c, d, n, k);
    }
    function add64() {
        var a = 0, b = 0, c = 0, d = 0, m16 = 65535, l, h, i;
        for(i = 0; i < arguments.length; i++){
            l = arguments[i].lo;
            h = arguments[i].hi;
            a += l & m16;
            b += l >>> 16;
            c += h & m16;
            d += h >>> 16;
        }
        b += a >>> 16;
        c += b >>> 16;
        d += c >>> 16;
        return new u64(c & m16 | d << 16, a & m16 | b << 16);
    }
    function shr64(x, c) {
        return new u64(x.hi >>> c, x.lo >>> c | x.hi << 32 - c);
    }
    function xor64() {
        var l = 0, h = 0, i;
        for(i = 0; i < arguments.length; i++){
            l ^= arguments[i].lo;
            h ^= arguments[i].hi;
        }
        return new u64(h, l);
    }
    function R(x, c) {
        var h, l, c1 = 32 - c;
        if (c < 32) {
            h = x.hi >>> c | x.lo << c1;
            l = x.lo >>> c | x.hi << c1;
        } else if (c < 64) {
            h = x.lo >>> c | x.hi << c1;
            l = x.hi >>> c | x.lo << c1;
        }
        return new u64(h, l);
    }
    function Ch(x, y, z) {
        var h = x.hi & y.hi ^ ~x.hi & z.hi, l = x.lo & y.lo ^ ~x.lo & z.lo;
        return new u64(h, l);
    }
    function Maj(x, y, z) {
        var h = x.hi & y.hi ^ x.hi & z.hi ^ y.hi & z.hi, l = x.lo & y.lo ^ x.lo & z.lo ^ y.lo & z.lo;
        return new u64(h, l);
    }
    function Sigma0(x) {
        return xor64(R(x, 28), R(x, 34), R(x, 39));
    }
    function Sigma1(x) {
        return xor64(R(x, 14), R(x, 18), R(x, 41));
    }
    function sigma0(x) {
        return xor64(R(x, 1), R(x, 8), shr64(x, 7));
    }
    function sigma1(x) {
        return xor64(R(x, 19), R(x, 61), shr64(x, 6));
    }
    var K = [
        new u64(0x428a2f98, 0xd728ae22),
        new u64(0x71374491, 0x23ef65cd),
        new u64(0xb5c0fbcf, 0xec4d3b2f),
        new u64(0xe9b5dba5, 0x8189dbbc),
        new u64(0x3956c25b, 0xf348b538),
        new u64(0x59f111f1, 0xb605d019),
        new u64(0x923f82a4, 0xaf194f9b),
        new u64(0xab1c5ed5, 0xda6d8118),
        new u64(0xd807aa98, 0xa3030242),
        new u64(0x12835b01, 0x45706fbe),
        new u64(0x243185be, 0x4ee4b28c),
        new u64(0x550c7dc3, 0xd5ffb4e2),
        new u64(0x72be5d74, 0xf27b896f),
        new u64(0x80deb1fe, 0x3b1696b1),
        new u64(0x9bdc06a7, 0x25c71235),
        new u64(0xc19bf174, 0xcf692694),
        new u64(0xe49b69c1, 0x9ef14ad2),
        new u64(0xefbe4786, 0x384f25e3),
        new u64(0x0fc19dc6, 0x8b8cd5b5),
        new u64(0x240ca1cc, 0x77ac9c65),
        new u64(0x2de92c6f, 0x592b0275),
        new u64(0x4a7484aa, 0x6ea6e483),
        new u64(0x5cb0a9dc, 0xbd41fbd4),
        new u64(0x76f988da, 0x831153b5),
        new u64(0x983e5152, 0xee66dfab),
        new u64(0xa831c66d, 0x2db43210),
        new u64(0xb00327c8, 0x98fb213f),
        new u64(0xbf597fc7, 0xbeef0ee4),
        new u64(0xc6e00bf3, 0x3da88fc2),
        new u64(0xd5a79147, 0x930aa725),
        new u64(0x06ca6351, 0xe003826f),
        new u64(0x14292967, 0x0a0e6e70),
        new u64(0x27b70a85, 0x46d22ffc),
        new u64(0x2e1b2138, 0x5c26c926),
        new u64(0x4d2c6dfc, 0x5ac42aed),
        new u64(0x53380d13, 0x9d95b3df),
        new u64(0x650a7354, 0x8baf63de),
        new u64(0x766a0abb, 0x3c77b2a8),
        new u64(0x81c2c92e, 0x47edaee6),
        new u64(0x92722c85, 0x1482353b),
        new u64(0xa2bfe8a1, 0x4cf10364),
        new u64(0xa81a664b, 0xbc423001),
        new u64(0xc24b8b70, 0xd0f89791),
        new u64(0xc76c51a3, 0x0654be30),
        new u64(0xd192e819, 0xd6ef5218),
        new u64(0xd6990624, 0x5565a910),
        new u64(0xf40e3585, 0x5771202a),
        new u64(0x106aa070, 0x32bbd1b8),
        new u64(0x19a4c116, 0xb8d2d0c8),
        new u64(0x1e376c08, 0x5141ab53),
        new u64(0x2748774c, 0xdf8eeb99),
        new u64(0x34b0bcb5, 0xe19b48a8),
        new u64(0x391c0cb3, 0xc5c95a63),
        new u64(0x4ed8aa4a, 0xe3418acb),
        new u64(0x5b9cca4f, 0x7763e373),
        new u64(0x682e6ff3, 0xd6b2b8a3),
        new u64(0x748f82ee, 0x5defb2fc),
        new u64(0x78a5636f, 0x43172f60),
        new u64(0x84c87814, 0xa1f0ab72),
        new u64(0x8cc70208, 0x1a6439ec),
        new u64(0x90befffa, 0x23631e28),
        new u64(0xa4506ceb, 0xde82bde9),
        new u64(0xbef9a3f7, 0xb2c67915),
        new u64(0xc67178f2, 0xe372532b),
        new u64(0xca273ece, 0xea26619c),
        new u64(0xd186b8c7, 0x21c0c207),
        new u64(0xeada7dd6, 0xcde0eb1e),
        new u64(0xf57d4f7f, 0xee6ed178),
        new u64(0x06f067aa, 0x72176fba),
        new u64(0x0a637dc5, 0xa2c898a6),
        new u64(0x113f9804, 0xbef90dae),
        new u64(0x1b710b35, 0x131c471b),
        new u64(0x28db77f5, 0x23047d84),
        new u64(0x32caab7b, 0x40c72493),
        new u64(0x3c9ebe0a, 0x15c9bebc),
        new u64(0x431d67c4, 0x9c100d4c),
        new u64(0x4cc5d4be, 0xcb3e42b6),
        new u64(0x597f299c, 0xfc657e2a),
        new u64(0x5fcb6fab, 0x3ad6faec),
        new u64(0x6c44198c, 0x4a475817)
    ];
    function crypto_hashblocks(x, m, n) {
        var z = [], b = [], a = [], w = [], t, i, j;
        for(i = 0; i < 8; i++)z[i] = a[i] = dl64(x, 8 * i);
        var pos = 0;
        while(n >= 128){
            for(i = 0; i < 16; i++)w[i] = dl64(m, 8 * i + pos);
            for(i = 0; i < 80; i++){
                for(j = 0; j < 8; j++)b[j] = a[j];
                t = add64(a[7], Sigma1(a[4]), Ch(a[4], a[5], a[6]), K[i], w[i % 16]);
                b[7] = add64(t, Sigma0(a[0]), Maj(a[0], a[1], a[2]));
                b[3] = add64(b[3], t);
                for(j = 0; j < 8; j++)a[(j + 1) % 8] = b[j];
                if (i % 16 === 15) {
                    for(j = 0; j < 16; j++){
                        w[j] = add64(w[j], w[(j + 9) % 16], sigma0(w[(j + 1) % 16]), sigma1(w[(j + 14) % 16]));
                    }
                }
            }
            for(i = 0; i < 8; i++){
                a[i] = add64(a[i], z[i]);
                z[i] = a[i];
            }
            pos += 128;
            n -= 128;
        }
        for(i = 0; i < 8; i++)ts64(x, 8 * i, z[i]);
        return n;
    }
    var iv = new Uint8Array([
        0x6a,
        0x09,
        0xe6,
        0x67,
        0xf3,
        0xbc,
        0xc9,
        0x08,
        0xbb,
        0x67,
        0xae,
        0x85,
        0x84,
        0xca,
        0xa7,
        0x3b,
        0x3c,
        0x6e,
        0xf3,
        0x72,
        0xfe,
        0x94,
        0xf8,
        0x2b,
        0xa5,
        0x4f,
        0xf5,
        0x3a,
        0x5f,
        0x1d,
        0x36,
        0xf1,
        0x51,
        0x0e,
        0x52,
        0x7f,
        0xad,
        0xe6,
        0x82,
        0xd1,
        0x9b,
        0x05,
        0x68,
        0x8c,
        0x2b,
        0x3e,
        0x6c,
        0x1f,
        0x1f,
        0x83,
        0xd9,
        0xab,
        0xfb,
        0x41,
        0xbd,
        0x6b,
        0x5b,
        0xe0,
        0xcd,
        0x19,
        0x13,
        0x7e,
        0x21,
        0x79
    ]);
    function crypto_hash(out, m, n) {
        var h = new Uint8Array(64), x = new Uint8Array(256);
        var i, b = n;
        for(i = 0; i < 64; i++)h[i] = iv[i];
        crypto_hashblocks(h, m, n);
        n %= 128;
        for(i = 0; i < 256; i++)x[i] = 0;
        for(i = 0; i < n; i++)x[i] = m[b - n + i];
        x[n] = 128;
        n = 256 - 128 * (n < 112 ? 1 : 0);
        x[n - 9] = 0;
        ts64(x, n - 8, new u64(b / 0x20000000 | 0, b << 3));
        crypto_hashblocks(h, x, n);
        for(i = 0; i < 64; i++)out[i] = h[i];
        return 0;
    }
    function add(p, q) {
        var a = gf(), b = gf(), c = gf(), d = gf(), e = gf(), f = gf(), g = gf(), h = gf(), t = gf();
        Z(a, p[1], p[0]);
        Z(t, q[1], q[0]);
        M(a, a, t);
        A(b, p[0], p[1]);
        A(t, q[0], q[1]);
        M(b, b, t);
        M(c, p[3], q[3]);
        M(c, c, D2);
        M(d, p[2], q[2]);
        A(d, d, d);
        Z(e, b, a);
        Z(f, d, c);
        A(g, d, c);
        A(h, b, a);
        M(p[0], e, f);
        M(p[1], h, g);
        M(p[2], g, f);
        M(p[3], e, h);
    }
    function cswap(p, q, b) {
        var i;
        for(i = 0; i < 4; i++){
            sel25519(p[i], q[i], b);
        }
    }
    function pack(r, p) {
        var tx = gf(), ty = gf(), zi = gf();
        inv25519(zi, p[2]);
        M(tx, p[0], zi);
        M(ty, p[1], zi);
        pack25519(r, ty);
        r[31] ^= par25519(tx) << 7;
    }
    function scalarmult(p, q, s) {
        var b, i;
        set25519(p[0], gf0);
        set25519(p[1], gf1);
        set25519(p[2], gf1);
        set25519(p[3], gf0);
        for(i = 255; i >= 0; --i){
            b = s[i / 8 | 0] >> (i & 7) & 1;
            cswap(p, q, b);
            add(q, p);
            add(p, p);
            cswap(p, q, b);
        }
    }
    function scalarbase(p, s) {
        var q = [
            gf(),
            gf(),
            gf(),
            gf()
        ];
        set25519(q[0], X);
        set25519(q[1], Y);
        set25519(q[2], gf1);
        M(q[3], X, Y);
        scalarmult(p, q, s);
    }
    function crypto_sign_keypair(pk, sk, seeded) {
        var d = new Uint8Array(64);
        var p = [
            gf(),
            gf(),
            gf(),
            gf()
        ];
        var i;
        if (!seeded) randombytes(sk, 32);
        crypto_hash(d, sk, 32);
        d[0] &= 248;
        d[31] &= 127;
        d[31] |= 64;
        scalarbase(p, d);
        pack(pk, p);
        for(i = 0; i < 32; i++)sk[i + 32] = pk[i];
        return 0;
    }
    var L = new Float64Array([
        0xed,
        0xd3,
        0xf5,
        0x5c,
        0x1a,
        0x63,
        0x12,
        0x58,
        0xd6,
        0x9c,
        0xf7,
        0xa2,
        0xde,
        0xf9,
        0xde,
        0x14,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0x10
    ]);
    function modL(r, x) {
        var carry, i, j, k;
        for(i = 63; i >= 32; --i){
            carry = 0;
            for(j = i - 32, k = i - 12; j < k; ++j){
                x[j] += carry - 16 * x[i] * L[j - (i - 32)];
                carry = Math.floor((x[j] + 128) / 256);
                x[j] -= carry * 256;
            }
            x[j] += carry;
            x[i] = 0;
        }
        carry = 0;
        for(j = 0; j < 32; j++){
            x[j] += carry - (x[31] >> 4) * L[j];
            carry = x[j] >> 8;
            x[j] &= 255;
        }
        for(j = 0; j < 32; j++)x[j] -= carry * L[j];
        for(i = 0; i < 32; i++){
            x[i + 1] += x[i] >> 8;
            r[i] = x[i] & 255;
        }
    }
    function reduce(r) {
        var x = new Float64Array(64), i;
        for(i = 0; i < 64; i++)x[i] = r[i];
        for(i = 0; i < 64; i++)r[i] = 0;
        modL(r, x);
    }
    function crypto_sign(sm, m, n, sk) {
        var d = new Uint8Array(64), h = new Uint8Array(64), r = new Uint8Array(64);
        var i, j, x = new Float64Array(64);
        var p = [
            gf(),
            gf(),
            gf(),
            gf()
        ];
        crypto_hash(d, sk, 32);
        d[0] &= 248;
        d[31] &= 127;
        d[31] |= 64;
        var smlen = n + 64;
        for(i = 0; i < n; i++)sm[64 + i] = m[i];
        for(i = 0; i < 32; i++)sm[32 + i] = d[32 + i];
        crypto_hash(r, sm.subarray(32), n + 32);
        reduce(r);
        scalarbase(p, r);
        pack(sm, p);
        for(i = 32; i < 64; i++)sm[i] = sk[i];
        crypto_hash(h, sm, n + 64);
        reduce(h);
        for(i = 0; i < 64; i++)x[i] = 0;
        for(i = 0; i < 32; i++)x[i] = r[i];
        for(i = 0; i < 32; i++){
            for(j = 0; j < 32; j++){
                x[i + j] += h[i] * d[j];
            }
        }
        modL(sm.subarray(32), x);
        return smlen;
    }
    function unpackneg(r, p) {
        var t = gf(), chk = gf(), num = gf(), den = gf(), den2 = gf(), den4 = gf(), den6 = gf();
        set25519(r[2], gf1);
        unpack25519(r[1], p);
        S(num, r[1]);
        M(den, num, D);
        Z(num, num, r[2]);
        A(den, r[2], den);
        S(den2, den);
        S(den4, den2);
        M(den6, den4, den2);
        M(t, den6, num);
        M(t, t, den);
        pow2523(t, t);
        M(t, t, num);
        M(t, t, den);
        M(t, t, den);
        M(r[0], t, den);
        S(chk, r[0]);
        M(chk, chk, den);
        if (neq25519(chk, num)) M(r[0], r[0], I);
        S(chk, r[0]);
        M(chk, chk, den);
        if (neq25519(chk, num)) return -1;
        if (par25519(r[0]) === p[31] >> 7) Z(r[0], gf0, r[0]);
        M(r[3], r[0], r[1]);
        return 0;
    }
    function crypto_sign_open(m, sm, n, pk) {
        var i;
        var t = new Uint8Array(32), h = new Uint8Array(64);
        var p = [
            gf(),
            gf(),
            gf(),
            gf()
        ], q = [
            gf(),
            gf(),
            gf(),
            gf()
        ];
        if (n < 64) return -1;
        if (unpackneg(q, pk)) return -1;
        for(i = 0; i < n; i++)m[i] = sm[i];
        for(i = 0; i < 32; i++)m[i + 32] = pk[i];
        crypto_hash(h, m, n);
        reduce(h);
        scalarmult(p, q, h);
        scalarbase(q, sm.subarray(32));
        add(p, q);
        pack(t, p);
        n -= 64;
        if (crypto_verify_32(sm, 0, t, 0)) {
            for(i = 0; i < n; i++)m[i] = 0;
            return -1;
        }
        for(i = 0; i < n; i++)m[i] = sm[i + 64];
        return n;
    }
    var crypto_secretbox_KEYBYTES = 32, crypto_secretbox_NONCEBYTES = 24, crypto_secretbox_ZEROBYTES = 32, crypto_secretbox_BOXZEROBYTES = 16, crypto_scalarmult_BYTES = 32, crypto_scalarmult_SCALARBYTES = 32, crypto_box_PUBLICKEYBYTES = 32, crypto_box_SECRETKEYBYTES = 32, crypto_box_BEFORENMBYTES = 32, crypto_box_NONCEBYTES = crypto_secretbox_NONCEBYTES, crypto_box_ZEROBYTES = crypto_secretbox_ZEROBYTES, crypto_box_BOXZEROBYTES = crypto_secretbox_BOXZEROBYTES, crypto_sign_BYTES = 64, crypto_sign_PUBLICKEYBYTES = 32, crypto_sign_SECRETKEYBYTES = 64, crypto_sign_SEEDBYTES = 32, crypto_hash_BYTES = 64;
    nacl.lowlevel = {
        crypto_core_hsalsa20: crypto_core_hsalsa20,
        crypto_stream_xor: crypto_stream_xor,
        crypto_stream: crypto_stream,
        crypto_stream_salsa20_xor: crypto_stream_salsa20_xor,
        crypto_stream_salsa20: crypto_stream_salsa20,
        crypto_onetimeauth: crypto_onetimeauth,
        crypto_onetimeauth_verify: crypto_onetimeauth_verify,
        crypto_verify_16: crypto_verify_16,
        crypto_verify_32: crypto_verify_32,
        crypto_secretbox: crypto_secretbox,
        crypto_secretbox_open: crypto_secretbox_open,
        crypto_scalarmult: crypto_scalarmult,
        crypto_scalarmult_base: crypto_scalarmult_base,
        crypto_box_beforenm: crypto_box_beforenm,
        crypto_box_afternm: crypto_box_afternm,
        crypto_box: crypto_box,
        crypto_box_open: crypto_box_open,
        crypto_box_keypair: crypto_box_keypair,
        crypto_hash: crypto_hash,
        crypto_sign: crypto_sign,
        crypto_sign_keypair: crypto_sign_keypair,
        crypto_sign_open: crypto_sign_open,
        crypto_secretbox_KEYBYTES: crypto_secretbox_KEYBYTES,
        crypto_secretbox_NONCEBYTES: crypto_secretbox_NONCEBYTES,
        crypto_secretbox_ZEROBYTES: crypto_secretbox_ZEROBYTES,
        crypto_secretbox_BOXZEROBYTES: crypto_secretbox_BOXZEROBYTES,
        crypto_scalarmult_BYTES: crypto_scalarmult_BYTES,
        crypto_scalarmult_SCALARBYTES: crypto_scalarmult_SCALARBYTES,
        crypto_box_PUBLICKEYBYTES: crypto_box_PUBLICKEYBYTES,
        crypto_box_SECRETKEYBYTES: crypto_box_SECRETKEYBYTES,
        crypto_box_BEFORENMBYTES: crypto_box_BEFORENMBYTES,
        crypto_box_NONCEBYTES: crypto_box_NONCEBYTES,
        crypto_box_ZEROBYTES: crypto_box_ZEROBYTES,
        crypto_box_BOXZEROBYTES: crypto_box_BOXZEROBYTES,
        crypto_sign_BYTES: crypto_sign_BYTES,
        crypto_sign_PUBLICKEYBYTES: crypto_sign_PUBLICKEYBYTES,
        crypto_sign_SECRETKEYBYTES: crypto_sign_SECRETKEYBYTES,
        crypto_sign_SEEDBYTES: crypto_sign_SEEDBYTES,
        crypto_hash_BYTES: crypto_hash_BYTES,
        gf: gf,
        D: D,
        L: L,
        pack25519: pack25519,
        unpack25519: unpack25519,
        M: M,
        A: A,
        S: S,
        Z: Z,
        pow2523: pow2523,
        add: add,
        set25519: set25519,
        modL: modL,
        scalarmult: scalarmult,
        scalarbase: scalarbase
    };
    function checkLengths(k, n) {
        if (k.length !== crypto_secretbox_KEYBYTES) throw new Error('bad key size');
        if (n.length !== crypto_secretbox_NONCEBYTES) throw new Error('bad nonce size');
    }
    function checkBoxLengths(pk, sk) {
        if (pk.length !== crypto_box_PUBLICKEYBYTES) throw new Error('bad public key size');
        if (sk.length !== crypto_box_SECRETKEYBYTES) throw new Error('bad secret key size');
    }
    function checkArrayTypes() {
        for(var i = 0; i < arguments.length; i++){
            if (!(arguments[i] instanceof Uint8Array)) throw new TypeError('unexpected type, use Uint8Array');
        }
    }
    function cleanup(arr) {
        for(var i = 0; i < arr.length; i++)arr[i] = 0;
    }
    nacl.randomBytes = function(n) {
        var b = new Uint8Array(n);
        randombytes(b, n);
        return b;
    };
    nacl.secretbox = function(msg, nonce, key) {
        checkArrayTypes(msg, nonce, key);
        checkLengths(key, nonce);
        var m = new Uint8Array(crypto_secretbox_ZEROBYTES + msg.length);
        var c = new Uint8Array(m.length);
        for(var i = 0; i < msg.length; i++)m[i + crypto_secretbox_ZEROBYTES] = msg[i];
        crypto_secretbox(c, m, m.length, nonce, key);
        return c.subarray(crypto_secretbox_BOXZEROBYTES);
    };
    nacl.secretbox.open = function(box, nonce, key) {
        checkArrayTypes(box, nonce, key);
        checkLengths(key, nonce);
        var c = new Uint8Array(crypto_secretbox_BOXZEROBYTES + box.length);
        var m = new Uint8Array(c.length);
        for(var i = 0; i < box.length; i++)c[i + crypto_secretbox_BOXZEROBYTES] = box[i];
        if (c.length < 32) return null;
        if (crypto_secretbox_open(m, c, c.length, nonce, key) !== 0) return null;
        return m.subarray(crypto_secretbox_ZEROBYTES);
    };
    nacl.secretbox.keyLength = crypto_secretbox_KEYBYTES;
    nacl.secretbox.nonceLength = crypto_secretbox_NONCEBYTES;
    nacl.secretbox.overheadLength = crypto_secretbox_BOXZEROBYTES;
    nacl.scalarMult = function(n, p) {
        checkArrayTypes(n, p);
        if (n.length !== crypto_scalarmult_SCALARBYTES) throw new Error('bad n size');
        if (p.length !== crypto_scalarmult_BYTES) throw new Error('bad p size');
        var q = new Uint8Array(crypto_scalarmult_BYTES);
        crypto_scalarmult(q, n, p);
        return q;
    };
    nacl.scalarMult.base = function(n) {
        checkArrayTypes(n);
        if (n.length !== crypto_scalarmult_SCALARBYTES) throw new Error('bad n size');
        var q = new Uint8Array(crypto_scalarmult_BYTES);
        crypto_scalarmult_base(q, n);
        return q;
    };
    nacl.scalarMult.scalarLength = crypto_scalarmult_SCALARBYTES;
    nacl.scalarMult.groupElementLength = crypto_scalarmult_BYTES;
    nacl.box = function(msg, nonce, publicKey, secretKey) {
        var k = nacl.box.before(publicKey, secretKey);
        return nacl.secretbox(msg, nonce, k);
    };
    nacl.box.before = function(publicKey, secretKey) {
        checkArrayTypes(publicKey, secretKey);
        checkBoxLengths(publicKey, secretKey);
        var k = new Uint8Array(crypto_box_BEFORENMBYTES);
        crypto_box_beforenm(k, publicKey, secretKey);
        return k;
    };
    nacl.box.after = nacl.secretbox;
    nacl.box.open = function(msg, nonce, publicKey, secretKey) {
        var k = nacl.box.before(publicKey, secretKey);
        return nacl.secretbox.open(msg, nonce, k);
    };
    nacl.box.open.after = nacl.secretbox.open;
    nacl.box.keyPair = function() {
        var pk = new Uint8Array(crypto_box_PUBLICKEYBYTES);
        var sk = new Uint8Array(crypto_box_SECRETKEYBYTES);
        crypto_box_keypair(pk, sk);
        return {
            publicKey: pk,
            secretKey: sk
        };
    };
    nacl.box.keyPair.fromSecretKey = function(secretKey) {
        checkArrayTypes(secretKey);
        if (secretKey.length !== crypto_box_SECRETKEYBYTES) throw new Error('bad secret key size');
        var pk = new Uint8Array(crypto_box_PUBLICKEYBYTES);
        crypto_scalarmult_base(pk, secretKey);
        return {
            publicKey: pk,
            secretKey: new Uint8Array(secretKey)
        };
    };
    nacl.box.publicKeyLength = crypto_box_PUBLICKEYBYTES;
    nacl.box.secretKeyLength = crypto_box_SECRETKEYBYTES;
    nacl.box.sharedKeyLength = crypto_box_BEFORENMBYTES;
    nacl.box.nonceLength = crypto_box_NONCEBYTES;
    nacl.box.overheadLength = nacl.secretbox.overheadLength;
    nacl.sign = function(msg, secretKey) {
        checkArrayTypes(msg, secretKey);
        if (secretKey.length !== crypto_sign_SECRETKEYBYTES) throw new Error('bad secret key size');
        var signedMsg = new Uint8Array(crypto_sign_BYTES + msg.length);
        crypto_sign(signedMsg, msg, msg.length, secretKey);
        return signedMsg;
    };
    nacl.sign.open = function(signedMsg, publicKey) {
        checkArrayTypes(signedMsg, publicKey);
        if (publicKey.length !== crypto_sign_PUBLICKEYBYTES) throw new Error('bad public key size');
        var tmp = new Uint8Array(signedMsg.length);
        var mlen = crypto_sign_open(tmp, signedMsg, signedMsg.length, publicKey);
        if (mlen < 0) return null;
        var m = new Uint8Array(mlen);
        for(var i = 0; i < m.length; i++)m[i] = tmp[i];
        return m;
    };
    nacl.sign.detached = function(msg, secretKey) {
        var signedMsg = nacl.sign(msg, secretKey);
        var sig = new Uint8Array(crypto_sign_BYTES);
        for(var i = 0; i < sig.length; i++)sig[i] = signedMsg[i];
        return sig;
    };
    nacl.sign.detached.verify = function(msg, sig, publicKey) {
        checkArrayTypes(msg, sig, publicKey);
        if (sig.length !== crypto_sign_BYTES) throw new Error('bad signature size');
        if (publicKey.length !== crypto_sign_PUBLICKEYBYTES) throw new Error('bad public key size');
        var sm = new Uint8Array(crypto_sign_BYTES + msg.length);
        var m = new Uint8Array(crypto_sign_BYTES + msg.length);
        var i;
        for(i = 0; i < crypto_sign_BYTES; i++)sm[i] = sig[i];
        for(i = 0; i < msg.length; i++)sm[i + crypto_sign_BYTES] = msg[i];
        return crypto_sign_open(m, sm, sm.length, publicKey) >= 0;
    };
    nacl.sign.keyPair = function() {
        var pk = new Uint8Array(crypto_sign_PUBLICKEYBYTES);
        var sk = new Uint8Array(crypto_sign_SECRETKEYBYTES);
        crypto_sign_keypair(pk, sk);
        return {
            publicKey: pk,
            secretKey: sk
        };
    };
    nacl.sign.keyPair.fromSecretKey = function(secretKey) {
        checkArrayTypes(secretKey);
        if (secretKey.length !== crypto_sign_SECRETKEYBYTES) throw new Error('bad secret key size');
        var pk = new Uint8Array(crypto_sign_PUBLICKEYBYTES);
        for(var i = 0; i < pk.length; i++)pk[i] = secretKey[32 + i];
        return {
            publicKey: pk,
            secretKey: new Uint8Array(secretKey)
        };
    };
    nacl.sign.keyPair.fromSeed = function(seed) {
        checkArrayTypes(seed);
        if (seed.length !== crypto_sign_SEEDBYTES) throw new Error('bad seed size');
        var pk = new Uint8Array(crypto_sign_PUBLICKEYBYTES);
        var sk = new Uint8Array(crypto_sign_SECRETKEYBYTES);
        for(var i = 0; i < 32; i++)sk[i] = seed[i];
        crypto_sign_keypair(pk, sk, true);
        return {
            publicKey: pk,
            secretKey: sk
        };
    };
    nacl.sign.publicKeyLength = crypto_sign_PUBLICKEYBYTES;
    nacl.sign.secretKeyLength = crypto_sign_SECRETKEYBYTES;
    nacl.sign.seedLength = crypto_sign_SEEDBYTES;
    nacl.sign.signatureLength = crypto_sign_BYTES;
    nacl.hash = function(msg) {
        checkArrayTypes(msg);
        var h = new Uint8Array(crypto_hash_BYTES);
        crypto_hash(h, msg, msg.length);
        return h;
    };
    nacl.hash.hashLength = crypto_hash_BYTES;
    nacl.verify = function(x, y) {
        checkArrayTypes(x, y);
        if (x.length === 0 || y.length === 0) return false;
        if (x.length !== y.length) return false;
        return vn(x, 0, y, 0, x.length) === 0 ? true : false;
    };
    nacl.setPRNG = function(fn) {
        randombytes = fn;
    };
    (function() {
        var crypto1 = typeof globalThis !== 'undefined' ? globalThis.crypto || globalThis.msCrypto : null;
        if (crypto1 && crypto1.getRandomValues) {
            var QUOTA = 65536;
            nacl.setPRNG(function(x, n) {
                var i, v = new Uint8Array(n);
                for(i = 0; i < n; i += QUOTA){
                    crypto1.getRandomValues(v.subarray(i, i + Math.min(n - i, QUOTA)));
                }
                for(i = 0; i < n; i++)x[i] = v[i];
                cleanup(v);
            });
        } else if (typeof require !== 'undefined') {
            crypto1 = require('crypto');
            if (crypto1 && crypto1.randomBytes) {
                nacl.setPRNG(function(x, n) {
                    var i, v = crypto1.randomBytes(n);
                    for(i = 0; i < n; i++)x[i] = v[i];
                    cleanup(v);
                });
            }
        }
    })();
})(typeof module !== 'undefined' && module.exports ? module.exports : globalThis.nacl = globalThis.nacl || {});
const nacl = typeof module !== 'undefined' && module.exports ? module.exports : globalThis.nacl;
const denoHelper = {
    fromSeed: nacl.sign.keyPair.fromSeed,
    sign: nacl.sign.detached,
    verify: nacl.sign.detached.verify,
    randomBytes: nacl.randomBytes
};
let helper;
function setEd25519Helper(lib) {
    helper = lib;
}
function getEd25519Helper() {
    return helper;
}
const crc16tab = new Uint16Array([
    0x0000,
    0x1021,
    0x2042,
    0x3063,
    0x4084,
    0x50a5,
    0x60c6,
    0x70e7,
    0x8108,
    0x9129,
    0xa14a,
    0xb16b,
    0xc18c,
    0xd1ad,
    0xe1ce,
    0xf1ef,
    0x1231,
    0x0210,
    0x3273,
    0x2252,
    0x52b5,
    0x4294,
    0x72f7,
    0x62d6,
    0x9339,
    0x8318,
    0xb37b,
    0xa35a,
    0xd3bd,
    0xc39c,
    0xf3ff,
    0xe3de,
    0x2462,
    0x3443,
    0x0420,
    0x1401,
    0x64e6,
    0x74c7,
    0x44a4,
    0x5485,
    0xa56a,
    0xb54b,
    0x8528,
    0x9509,
    0xe5ee,
    0xf5cf,
    0xc5ac,
    0xd58d,
    0x3653,
    0x2672,
    0x1611,
    0x0630,
    0x76d7,
    0x66f6,
    0x5695,
    0x46b4,
    0xb75b,
    0xa77a,
    0x9719,
    0x8738,
    0xf7df,
    0xe7fe,
    0xd79d,
    0xc7bc,
    0x48c4,
    0x58e5,
    0x6886,
    0x78a7,
    0x0840,
    0x1861,
    0x2802,
    0x3823,
    0xc9cc,
    0xd9ed,
    0xe98e,
    0xf9af,
    0x8948,
    0x9969,
    0xa90a,
    0xb92b,
    0x5af5,
    0x4ad4,
    0x7ab7,
    0x6a96,
    0x1a71,
    0x0a50,
    0x3a33,
    0x2a12,
    0xdbfd,
    0xcbdc,
    0xfbbf,
    0xeb9e,
    0x9b79,
    0x8b58,
    0xbb3b,
    0xab1a,
    0x6ca6,
    0x7c87,
    0x4ce4,
    0x5cc5,
    0x2c22,
    0x3c03,
    0x0c60,
    0x1c41,
    0xedae,
    0xfd8f,
    0xcdec,
    0xddcd,
    0xad2a,
    0xbd0b,
    0x8d68,
    0x9d49,
    0x7e97,
    0x6eb6,
    0x5ed5,
    0x4ef4,
    0x3e13,
    0x2e32,
    0x1e51,
    0x0e70,
    0xff9f,
    0xefbe,
    0xdfdd,
    0xcffc,
    0xbf1b,
    0xaf3a,
    0x9f59,
    0x8f78,
    0x9188,
    0x81a9,
    0xb1ca,
    0xa1eb,
    0xd10c,
    0xc12d,
    0xf14e,
    0xe16f,
    0x1080,
    0x00a1,
    0x30c2,
    0x20e3,
    0x5004,
    0x4025,
    0x7046,
    0x6067,
    0x83b9,
    0x9398,
    0xa3fb,
    0xb3da,
    0xc33d,
    0xd31c,
    0xe37f,
    0xf35e,
    0x02b1,
    0x1290,
    0x22f3,
    0x32d2,
    0x4235,
    0x5214,
    0x6277,
    0x7256,
    0xb5ea,
    0xa5cb,
    0x95a8,
    0x8589,
    0xf56e,
    0xe54f,
    0xd52c,
    0xc50d,
    0x34e2,
    0x24c3,
    0x14a0,
    0x0481,
    0x7466,
    0x6447,
    0x5424,
    0x4405,
    0xa7db,
    0xb7fa,
    0x8799,
    0x97b8,
    0xe75f,
    0xf77e,
    0xc71d,
    0xd73c,
    0x26d3,
    0x36f2,
    0x0691,
    0x16b0,
    0x6657,
    0x7676,
    0x4615,
    0x5634,
    0xd94c,
    0xc96d,
    0xf90e,
    0xe92f,
    0x99c8,
    0x89e9,
    0xb98a,
    0xa9ab,
    0x5844,
    0x4865,
    0x7806,
    0x6827,
    0x18c0,
    0x08e1,
    0x3882,
    0x28a3,
    0xcb7d,
    0xdb5c,
    0xeb3f,
    0xfb1e,
    0x8bf9,
    0x9bd8,
    0xabbb,
    0xbb9a,
    0x4a75,
    0x5a54,
    0x6a37,
    0x7a16,
    0x0af1,
    0x1ad0,
    0x2ab3,
    0x3a92,
    0xfd2e,
    0xed0f,
    0xdd6c,
    0xcd4d,
    0xbdaa,
    0xad8b,
    0x9de8,
    0x8dc9,
    0x7c26,
    0x6c07,
    0x5c64,
    0x4c45,
    0x3ca2,
    0x2c83,
    0x1ce0,
    0x0cc1,
    0xef1f,
    0xff3e,
    0xcf5d,
    0xdf7c,
    0xaf9b,
    0xbfba,
    0x8fd9,
    0x9ff8,
    0x6e17,
    0x7e36,
    0x4e55,
    0x5e74,
    0x2e93,
    0x3eb2,
    0x0ed1,
    0x1ef0
]);
class crc16 {
    static checksum(data) {
        let crc = 0;
        for(let i = 0; i < data.byteLength; i++){
            let b = data[i];
            crc = crc << 8 & 0xffff ^ crc16tab[(crc >> 8 ^ b) & 0x00FF];
        }
        return crc;
    }
    static validate(data, expected) {
        let ba = crc16.checksum(data);
        return ba == expected;
    }
}
const b32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
class base32 {
    static encode(src) {
        let bits = 0;
        let value = 0;
        let a = new Uint8Array(src);
        let buf = new Uint8Array(src.byteLength * 2);
        let j = 0;
        for(let i = 0; i < a.byteLength; i++){
            value = value << 8 | a[i];
            bits += 8;
            while(bits >= 5){
                let index = value >>> bits - 5 & 31;
                buf[j++] = b32Alphabet.charAt(index).charCodeAt(0);
                bits -= 5;
            }
        }
        if (bits > 0) {
            let index = value << 5 - bits & 31;
            buf[j++] = b32Alphabet.charAt(index).charCodeAt(0);
        }
        return buf.slice(0, j);
    }
    static decode(src) {
        let bits = 0;
        let __byte = 0;
        let j = 0;
        let a = new Uint8Array(src);
        let out = new Uint8Array(a.byteLength * 5 / 8 | 0);
        for(let i = 0; i < a.byteLength; i++){
            let v = String.fromCharCode(a[i]);
            let vv = b32Alphabet.indexOf(v);
            if (vv === -1) {
                throw new Error("Illegal Base32 character: " + a[i]);
            }
            __byte = __byte << 5 | vv;
            bits += 5;
            if (bits >= 8) {
                out[j++] = __byte >>> bits - 8 & 255;
                bits -= 8;
            }
        }
        return out.slice(0, j);
    }
}
class NKeysError extends Error {
    name;
    code;
    chainedError;
    constructor(code, chainedError){
        super(code);
        this.name = "NKeysError";
        this.code = code;
        this.chainedError = chainedError;
    }
}
function createOperator() {
    return createPair(Prefix.Operator);
}
function createAccount() {
    return createPair(Prefix.Account);
}
function createUser() {
    return createPair(Prefix.User);
}
var NKeysErrorCode;
(function(NKeysErrorCode) {
    NKeysErrorCode["InvalidPrefixByte"] = "nkeys: invalid prefix byte";
    NKeysErrorCode["InvalidKey"] = "nkeys: invalid key";
    NKeysErrorCode["InvalidPublicKey"] = "nkeys: invalid public key";
    NKeysErrorCode["InvalidSeedLen"] = "nkeys: invalid seed length";
    NKeysErrorCode["InvalidSeed"] = "nkeys: invalid seed";
    NKeysErrorCode["InvalidEncoding"] = "nkeys: invalid encoded key";
    NKeysErrorCode["InvalidSignature"] = "nkeys: signature verification failed";
    NKeysErrorCode["CannotSign"] = "nkeys: cannot sign, no private key available";
    NKeysErrorCode["PublicKeyOnly"] = "nkeys: no seed or private key available";
    NKeysErrorCode["InvalidChecksum"] = "nkeys: invalid checksum";
    NKeysErrorCode["SerializationError"] = "nkeys: serialization error";
    NKeysErrorCode["ApiError"] = "nkeys: api error";
    NKeysErrorCode["ClearedPair"] = "nkeys: pair is cleared";
})(NKeysErrorCode || (NKeysErrorCode = {}));
var Prefix;
(function(Prefix) {
    Prefix[Prefix["Seed"] = 144] = "Seed";
    Prefix[Prefix["Private"] = 120] = "Private";
    Prefix[Prefix["Operator"] = 112] = "Operator";
    Prefix[Prefix["Server"] = 104] = "Server";
    Prefix[Prefix["Cluster"] = 16] = "Cluster";
    Prefix[Prefix["Account"] = 0] = "Account";
    Prefix[Prefix["User"] = 160] = "User";
})(Prefix || (Prefix = {}));
class Prefixes {
    static isValidPublicPrefix(prefix) {
        return prefix == Prefix.Server || prefix == Prefix.Operator || prefix == Prefix.Cluster || prefix == Prefix.Account || prefix == Prefix.User;
    }
    static startsWithValidPrefix(s) {
        let c = s[0];
        return c == "S" || c == "P" || c == "O" || c == "N" || c == "C" || c == "A" || c == "U";
    }
    static isValidPrefix(prefix) {
        let v = this.parsePrefix(prefix);
        return v != -1;
    }
    static parsePrefix(v) {
        switch(v){
            case Prefix.Seed:
                return Prefix.Seed;
            case Prefix.Private:
                return Prefix.Private;
            case Prefix.Operator:
                return Prefix.Operator;
            case Prefix.Server:
                return Prefix.Server;
            case Prefix.Cluster:
                return Prefix.Cluster;
            case Prefix.Account:
                return Prefix.Account;
            case Prefix.User:
                return Prefix.User;
            default:
                return -1;
        }
    }
}
class Codec {
    static encode(prefix, src) {
        if (!src || !(src instanceof Uint8Array)) {
            throw new NKeysError(NKeysErrorCode.SerializationError);
        }
        if (!Prefixes.isValidPrefix(prefix)) {
            throw new NKeysError(NKeysErrorCode.InvalidPrefixByte);
        }
        return Codec._encode(false, prefix, src);
    }
    static encodeSeed(role, src) {
        if (!src) {
            throw new NKeysError(NKeysErrorCode.ApiError);
        }
        if (!Prefixes.isValidPublicPrefix(role)) {
            throw new NKeysError(NKeysErrorCode.InvalidPrefixByte);
        }
        if (src.byteLength !== 32) {
            throw new NKeysError(NKeysErrorCode.InvalidSeedLen);
        }
        return Codec._encode(true, role, src);
    }
    static decode(expected, src) {
        if (!Prefixes.isValidPrefix(expected)) {
            throw new NKeysError(NKeysErrorCode.InvalidPrefixByte);
        }
        const raw = Codec._decode(src);
        if (raw[0] !== expected) {
            throw new NKeysError(NKeysErrorCode.InvalidPrefixByte);
        }
        return raw.slice(1);
    }
    static decodeSeed(src) {
        const raw = Codec._decode(src);
        const prefix = Codec._decodePrefix(raw);
        if (prefix[0] != Prefix.Seed) {
            throw new NKeysError(NKeysErrorCode.InvalidSeed);
        }
        if (!Prefixes.isValidPublicPrefix(prefix[1])) {
            throw new NKeysError(NKeysErrorCode.InvalidPrefixByte);
        }
        return {
            buf: raw.slice(2),
            prefix: prefix[1]
        };
    }
    static _encode(seed, role, payload) {
        const payloadOffset = seed ? 2 : 1;
        const payloadLen = payload.byteLength;
        const cap = payloadOffset + payloadLen + 2;
        const checkOffset = payloadOffset + payloadLen;
        const raw = new Uint8Array(cap);
        if (seed) {
            const encodedPrefix = Codec._encodePrefix(Prefix.Seed, role);
            raw.set(encodedPrefix);
        } else {
            raw[0] = role;
        }
        raw.set(payload, payloadOffset);
        const checksum = crc16.checksum(raw.slice(0, checkOffset));
        const dv = new DataView(raw.buffer);
        dv.setUint16(checkOffset, checksum, true);
        return base32.encode(raw);
    }
    static _decode(src) {
        if (src.byteLength < 4) {
            throw new NKeysError(NKeysErrorCode.InvalidEncoding);
        }
        let raw;
        try {
            raw = base32.decode(src);
        } catch (ex) {
            throw new NKeysError(NKeysErrorCode.InvalidEncoding, ex);
        }
        const checkOffset = raw.byteLength - 2;
        const dv = new DataView(raw.buffer);
        const checksum = dv.getUint16(checkOffset, true);
        const payload = raw.slice(0, checkOffset);
        if (!crc16.validate(payload, checksum)) {
            throw new NKeysError(NKeysErrorCode.InvalidChecksum);
        }
        return payload;
    }
    static _encodePrefix(kind, role) {
        const b1 = kind | role >> 5;
        const b2 = (role & 31) << 3;
        return new Uint8Array([
            b1,
            b2
        ]);
    }
    static _decodePrefix(raw) {
        const b1 = raw[0] & 248;
        const b2 = (raw[0] & 7) << 5 | (raw[1] & 248) >> 3;
        return new Uint8Array([
            b1,
            b2
        ]);
    }
}
class KP {
    seed;
    constructor(seed){
        this.seed = seed;
    }
    getRawSeed() {
        if (!this.seed) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        let sd = Codec.decodeSeed(this.seed);
        return sd.buf;
    }
    getSeed() {
        if (!this.seed) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        return this.seed;
    }
    getPublicKey() {
        if (!this.seed) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        const sd = Codec.decodeSeed(this.seed);
        const kp = getEd25519Helper().fromSeed(this.getRawSeed());
        const buf = Codec.encode(sd.prefix, kp.publicKey);
        return new TextDecoder().decode(buf);
    }
    getPrivateKey() {
        if (!this.seed) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        const kp = getEd25519Helper().fromSeed(this.getRawSeed());
        return Codec.encode(Prefix.Private, kp.secretKey);
    }
    sign(input) {
        if (!this.seed) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        const kp = getEd25519Helper().fromSeed(this.getRawSeed());
        return getEd25519Helper().sign(input, kp.secretKey);
    }
    verify(input, sig) {
        if (!this.seed) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        const kp = getEd25519Helper().fromSeed(this.getRawSeed());
        return getEd25519Helper().verify(input, sig, kp.publicKey);
    }
    clear() {
        if (!this.seed) {
            return;
        }
        this.seed.fill(0);
        this.seed = undefined;
    }
}
function createPair(prefix) {
    const rawSeed = getEd25519Helper().randomBytes(32);
    let str = Codec.encodeSeed(prefix, new Uint8Array(rawSeed));
    return new KP(str);
}
class PublicKey {
    publicKey;
    constructor(publicKey){
        this.publicKey = publicKey;
    }
    getPublicKey() {
        if (!this.publicKey) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        return new TextDecoder().decode(this.publicKey);
    }
    getPrivateKey() {
        if (!this.publicKey) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        throw new NKeysError(NKeysErrorCode.PublicKeyOnly);
    }
    getSeed() {
        if (!this.publicKey) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        throw new NKeysError(NKeysErrorCode.PublicKeyOnly);
    }
    sign(_) {
        if (!this.publicKey) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        throw new NKeysError(NKeysErrorCode.CannotSign);
    }
    verify(input, sig) {
        if (!this.publicKey) {
            throw new NKeysError(NKeysErrorCode.ClearedPair);
        }
        let buf = Codec._decode(this.publicKey);
        return getEd25519Helper().verify(input, sig, buf.slice(1));
    }
    clear() {
        if (!this.publicKey) {
            return;
        }
        this.publicKey.fill(0);
        this.publicKey = undefined;
    }
}
function fromPublic(src) {
    const ba = new TextEncoder().encode(src);
    const raw = Codec._decode(ba);
    const prefix = Prefixes.parsePrefix(raw[0]);
    if (Prefixes.isValidPublicPrefix(prefix)) {
        return new PublicKey(ba);
    }
    throw new NKeysError(NKeysErrorCode.InvalidPublicKey);
}
function fromSeed(src) {
    Codec.decodeSeed(src);
    return new KP(src);
}
function encode1(bytes) {
    return btoa(String.fromCharCode(...bytes));
}
function decode1(b64str) {
    const bin = atob(b64str);
    const bytes = new Uint8Array(bin.length);
    for(let i = 0; i < bin.length; i++){
        bytes[i] = bin.charCodeAt(i);
    }
    return bytes;
}
setEd25519Helper(denoHelper);
const mod = {
    createAccount,
    createOperator,
    createPair,
    createUser,
    fromPublic,
    fromSeed,
    NKeysError,
    NKeysErrorCode,
    Prefix,
    decode: decode1,
    encode: encode1
};
function multiAuthenticator(authenticators) {
    return (nonce)=>{
        let auth = {};
        authenticators.forEach((a)=>{
            const args = a(nonce) || {};
            auth = Object.assign(auth, args);
        });
        return auth;
    };
}
function noAuthFn() {
    return ()=>{
        return;
    };
}
function usernamePasswordAuthenticator(user, pass) {
    return ()=>{
        const u = typeof user === "function" ? user() : user;
        const p = typeof pass === "function" ? pass() : pass;
        return {
            user: u,
            pass: p
        };
    };
}
function tokenAuthenticator(token) {
    return ()=>{
        const auth_token = typeof token === "function" ? token() : token;
        return {
            auth_token
        };
    };
}
function nkeyAuthenticator(seed) {
    return (nonce)=>{
        const s = typeof seed === "function" ? seed() : seed;
        const kp = s ? mod.fromSeed(s) : undefined;
        const nkey = kp ? kp.getPublicKey() : "";
        const challenge = TE.encode(nonce || "");
        const sigBytes = kp !== undefined && nonce ? kp.sign(challenge) : undefined;
        const sig = sigBytes ? mod.encode(sigBytes) : "";
        return {
            nkey,
            sig
        };
    };
}
function jwtAuthenticator(ajwt, seed) {
    return (nonce)=>{
        const jwt = typeof ajwt === "function" ? ajwt() : ajwt;
        const fn = nkeyAuthenticator(seed);
        const { nkey, sig } = fn(nonce);
        return {
            jwt,
            nkey,
            sig
        };
    };
}
function credsAuthenticator(creds) {
    const fn = typeof creds !== "function" ? ()=>creds : creds;
    const parse = ()=>{
        const CREDS = /\s*(?:(?:[-]{3,}[^\n]*[-]{3,}\n)(.+)(?:\n\s*[-]{3,}[^\n]*[-]{3,}\n))/ig;
        const s = TD.decode(fn());
        let m = CREDS.exec(s);
        if (!m) {
            throw NatsError.errorForCode(ErrorCode.BadCreds);
        }
        const jwt = m[1].trim();
        m = CREDS.exec(s);
        if (!m) {
            throw NatsError.errorForCode(ErrorCode.BadCreds);
        }
        if (!m) {
            throw NatsError.errorForCode(ErrorCode.BadCreds);
        }
        const seed = TE.encode(m[1].trim());
        return {
            jwt,
            seed
        };
    };
    const jwtFn = ()=>{
        const { jwt } = parse();
        return jwt;
    };
    const nkeyFn = ()=>{
        const { seed } = parse();
        return seed;
    };
    return jwtAuthenticator(jwtFn, nkeyFn);
}
const DEFAULT_PING_INTERVAL = 2 * 60 * 1000;
const DEFAULT_MAX_PING_OUT = 2;
const DEFAULT_RECONNECT_TIME_WAIT = 2 * 1000;
function defaultOptions() {
    return {
        maxPingOut: 2,
        maxReconnectAttempts: 10,
        noRandomize: false,
        pedantic: false,
        pingInterval: DEFAULT_PING_INTERVAL,
        reconnect: true,
        reconnectJitter: 100,
        reconnectJitterTLS: 1000,
        reconnectTimeWait: DEFAULT_RECONNECT_TIME_WAIT,
        tls: undefined,
        verbose: false,
        waitOnFirstConnect: false,
        ignoreAuthErrorAbort: false
    };
}
function buildAuthenticator(opts) {
    const buf = [];
    if (typeof opts.authenticator === "function") {
        buf.push(opts.authenticator);
    }
    if (Array.isArray(opts.authenticator)) {
        buf.push(...opts.authenticator);
    }
    if (opts.token) {
        buf.push(tokenAuthenticator(opts.token));
    }
    if (opts.user) {
        buf.push(usernamePasswordAuthenticator(opts.user, opts.pass));
    }
    return buf.length === 0 ? noAuthFn() : multiAuthenticator(buf);
}
function parseOptions(opts) {
    const dhp = `${DEFAULT_HOST}:${defaultPort()}`;
    opts = opts || {
        servers: [
            dhp
        ]
    };
    opts.servers = opts.servers || [];
    if (typeof opts.servers === "string") {
        opts.servers = [
            opts.servers
        ];
    }
    if (opts.servers.length > 0 && opts.port) {
        throw new NatsError("port and servers options are mutually exclusive", ErrorCode.InvalidOption);
    }
    if (opts.servers.length === 0 && opts.port) {
        opts.servers = [
            `${DEFAULT_HOST}:${opts.port}`
        ];
    }
    if (opts.servers && opts.servers.length === 0) {
        opts.servers = [
            dhp
        ];
    }
    const options = extend(defaultOptions(), opts);
    options.authenticator = buildAuthenticator(options);
    [
        "reconnectDelayHandler",
        "authenticator"
    ].forEach((n)=>{
        if (options[n] && typeof options[n] !== "function") {
            throw new NatsError(`${n} option should be a function`, ErrorCode.NotFunction);
        }
    });
    if (!options.reconnectDelayHandler) {
        options.reconnectDelayHandler = ()=>{
            let extra = options.tls ? options.reconnectJitterTLS : options.reconnectJitter;
            if (extra) {
                extra++;
                extra = Math.floor(Math.random() * extra);
            }
            return options.reconnectTimeWait + extra;
        };
    }
    if (options.inboxPrefix) {
        try {
            createInbox(options.inboxPrefix);
        } catch (err) {
            throw new NatsError(err.message, ErrorCode.ApiError);
        }
    }
    if (options.resolve === undefined) {
        options.resolve = typeof getResolveFn() === "function";
    }
    if (options.resolve) {
        if (typeof getResolveFn() !== "function") {
            throw new NatsError(`'resolve' is not supported on this client`, ErrorCode.InvalidOption);
        }
    }
    return options;
}
function checkOptions(info, options) {
    const { proto, tls_required: tlsRequired, tls_available: tlsAvailable } = info;
    if ((proto === undefined || proto < 1) && options.noEcho) {
        throw new NatsError("noEcho", ErrorCode.ServerOptionNotAvailable);
    }
    const tls = tlsRequired || tlsAvailable || false;
    if (options.tls && !tls) {
        throw new NatsError("tls", ErrorCode.ServerOptionNotAvailable);
    }
}
const FLUSH_THRESHOLD = 1024 * 32;
const INFO = /^INFO\s+([^\r\n]+)\r\n/i;
const PONG_CMD = encode("PONG\r\n");
const PING_CMD = encode("PING\r\n");
class Connect {
    echo;
    no_responders;
    protocol;
    verbose;
    pedantic;
    jwt;
    nkey;
    sig;
    user;
    pass;
    auth_token;
    tls_required;
    name;
    lang;
    version;
    headers;
    constructor(transport, opts, nonce){
        this.protocol = 1;
        this.version = transport.version;
        this.lang = transport.lang;
        this.echo = opts.noEcho ? false : undefined;
        this.verbose = opts.verbose;
        this.pedantic = opts.pedantic;
        this.tls_required = opts.tls ? true : undefined;
        this.name = opts.name;
        const creds = (opts && typeof opts.authenticator === "function" ? opts.authenticator(nonce) : {}) || {};
        extend(this, creds);
    }
}
class SubscriptionImpl extends QueuedIteratorImpl {
    sid;
    queue;
    draining;
    max;
    subject;
    drained;
    protocol;
    timer;
    info;
    cleanupFn;
    closed;
    requestSubject;
    constructor(protocol, subject, opts = {}){
        super();
        extend(this, opts);
        this.protocol = protocol;
        this.subject = subject;
        this.draining = false;
        this.noIterator = typeof opts.callback === "function";
        this.closed = deferred();
        const asyncTraces = !(protocol.options?.noAsyncTraces || false);
        if (opts.timeout) {
            this.timer = timeout(opts.timeout, asyncTraces);
            this.timer.then(()=>{
                this.timer = undefined;
            }).catch((err)=>{
                this.stop(err);
                if (this.noIterator) {
                    this.callback(err, {});
                }
            });
        }
        if (!this.noIterator) {
            this.iterClosed.then(()=>{
                this.closed.resolve();
                this.unsubscribe();
            });
        }
    }
    setPrePostHandlers(opts) {
        if (this.noIterator) {
            const uc = this.callback;
            const ingestion = opts.ingestionFilterFn ? opts.ingestionFilterFn : ()=>{
                return {
                    ingest: true,
                    protocol: false
                };
            };
            const filter = opts.protocolFilterFn ? opts.protocolFilterFn : ()=>{
                return true;
            };
            const dispatched = opts.dispatchedFn ? opts.dispatchedFn : ()=>{};
            this.callback = (err, msg)=>{
                const { ingest } = ingestion(msg);
                if (!ingest) {
                    return;
                }
                if (filter(msg)) {
                    uc(err, msg);
                    dispatched(msg);
                }
            };
        } else {
            this.protocolFilterFn = opts.protocolFilterFn;
            this.dispatchedFn = opts.dispatchedFn;
        }
    }
    callback(err, msg) {
        this.cancelTimeout();
        err ? this.stop(err) : this.push(msg);
    }
    close() {
        if (!this.isClosed()) {
            this.cancelTimeout();
            const fn = ()=>{
                this.stop();
                if (this.cleanupFn) {
                    try {
                        this.cleanupFn(this, this.info);
                    } catch (_err) {}
                }
                this.closed.resolve();
            };
            if (this.noIterator) {
                fn();
            } else {
                this.push(fn);
            }
        }
    }
    unsubscribe(max) {
        this.protocol.unsubscribe(this, max);
    }
    cancelTimeout() {
        if (this.timer) {
            this.timer.cancel();
            this.timer = undefined;
        }
    }
    drain() {
        if (this.protocol.isClosed()) {
            return Promise.reject(NatsError.errorForCode(ErrorCode.ConnectionClosed));
        }
        if (this.isClosed()) {
            return Promise.reject(NatsError.errorForCode(ErrorCode.SubClosed));
        }
        if (!this.drained) {
            this.draining = true;
            this.protocol.unsub(this);
            this.drained = this.protocol.flush(deferred()).then(()=>{
                this.protocol.subscriptions.cancel(this);
            }).catch(()=>{
                this.protocol.subscriptions.cancel(this);
            });
        }
        return this.drained;
    }
    isDraining() {
        return this.draining;
    }
    isClosed() {
        return this.done;
    }
    getSubject() {
        return this.subject;
    }
    getMax() {
        return this.max;
    }
    getID() {
        return this.sid;
    }
}
class Subscriptions {
    mux;
    subs;
    sidCounter;
    constructor(){
        this.sidCounter = 0;
        this.mux = null;
        this.subs = new Map();
    }
    size() {
        return this.subs.size;
    }
    add(s) {
        this.sidCounter++;
        s.sid = this.sidCounter;
        this.subs.set(s.sid, s);
        return s;
    }
    setMux(s) {
        this.mux = s;
        return s;
    }
    getMux() {
        return this.mux;
    }
    get(sid) {
        return this.subs.get(sid);
    }
    resub(s) {
        this.sidCounter++;
        this.subs.delete(s.sid);
        s.sid = this.sidCounter;
        this.subs.set(s.sid, s);
        return s;
    }
    all() {
        return Array.from(this.subs.values());
    }
    cancel(s) {
        if (s) {
            s.close();
            this.subs.delete(s.sid);
        }
    }
    handleError(err) {
        if (err && err.permissionContext) {
            const ctx = err.permissionContext;
            const subs = this.all();
            let sub;
            if (ctx.operation === "subscription") {
                sub = subs.find((s)=>{
                    return s.subject === ctx.subject && s.queue === ctx.queue;
                });
            }
            if (ctx.operation === "publish") {
                sub = subs.find((s)=>{
                    return s.requestSubject === ctx.subject;
                });
            }
            if (sub) {
                sub.callback(err, {});
                sub.close();
                this.subs.delete(sub.sid);
                return sub !== this.mux;
            }
        }
        return false;
    }
    close() {
        this.subs.forEach((sub)=>{
            sub.close();
        });
    }
}
class ProtocolHandler {
    connected;
    connectedOnce;
    infoReceived;
    info;
    muxSubscriptions;
    options;
    outbound;
    pongs;
    subscriptions;
    transport;
    noMorePublishing;
    connectError;
    publisher;
    _closed;
    closed;
    listeners;
    heartbeats;
    parser;
    outMsgs;
    inMsgs;
    outBytes;
    inBytes;
    pendingLimit;
    lastError;
    abortReconnect;
    whyClosed;
    servers;
    server;
    features;
    connectPromise;
    constructor(options, publisher){
        this._closed = false;
        this.connected = false;
        this.connectedOnce = false;
        this.infoReceived = false;
        this.noMorePublishing = false;
        this.abortReconnect = false;
        this.listeners = [];
        this.pendingLimit = FLUSH_THRESHOLD;
        this.outMsgs = 0;
        this.inMsgs = 0;
        this.outBytes = 0;
        this.inBytes = 0;
        this.options = options;
        this.publisher = publisher;
        this.subscriptions = new Subscriptions();
        this.muxSubscriptions = new MuxSubscription();
        this.outbound = new DataBuffer();
        this.pongs = [];
        this.whyClosed = "";
        this.pendingLimit = options.pendingLimit || this.pendingLimit;
        this.features = new Features({
            major: 0,
            minor: 0,
            micro: 0
        });
        this.connectPromise = null;
        const servers = typeof options.servers === "string" ? [
            options.servers
        ] : options.servers;
        this.servers = new Servers(servers, {
            randomize: !options.noRandomize
        });
        this.closed = deferred();
        this.parser = new Parser(this);
        this.heartbeats = new Heartbeat(this, this.options.pingInterval || DEFAULT_PING_INTERVAL, this.options.maxPingOut || DEFAULT_MAX_PING_OUT);
    }
    resetOutbound() {
        this.outbound.reset();
        const pongs = this.pongs;
        this.pongs = [];
        const err = NatsError.errorForCode(ErrorCode.Disconnect);
        err.stack = "";
        pongs.forEach((p)=>{
            p.reject(err);
        });
        this.parser = new Parser(this);
        this.infoReceived = false;
    }
    dispatchStatus(status) {
        this.listeners.forEach((q)=>{
            q.push(status);
        });
    }
    status() {
        const iter = new QueuedIteratorImpl();
        this.listeners.push(iter);
        return iter;
    }
    prepare() {
        if (this.transport) {
            this.transport.discard();
        }
        this.info = undefined;
        this.resetOutbound();
        const pong = deferred();
        pong.catch(()=>{});
        this.pongs.unshift(pong);
        this.connectError = (err)=>{
            pong.reject(err);
        };
        this.transport = newTransport();
        this.transport.closed().then(async (_err)=>{
            this.connected = false;
            if (!this.isClosed()) {
                await this.disconnected(this.transport.closeError || this.lastError);
                return;
            }
        });
        return pong;
    }
    disconnect() {
        this.dispatchStatus({
            type: DebugEvents.StaleConnection,
            data: ""
        });
        this.transport.disconnect();
    }
    reconnect() {
        if (this.connected) {
            this.dispatchStatus({
                type: DebugEvents.ClientInitiatedReconnect,
                data: ""
            });
            this.transport.disconnect();
        }
        return Promise.resolve();
    }
    async disconnected(err) {
        this.dispatchStatus({
            type: Events.Disconnect,
            data: this.servers.getCurrentServer().toString()
        });
        if (this.options.reconnect) {
            await this.dialLoop().then(()=>{
                this.dispatchStatus({
                    type: Events.Reconnect,
                    data: this.servers.getCurrentServer().toString()
                });
                if (this.lastError?.code === ErrorCode.AuthenticationExpired) {
                    this.lastError = undefined;
                }
            }).catch((err)=>{
                this._close(err);
            });
        } else {
            await this._close(err);
        }
    }
    async dial(srv) {
        const pong = this.prepare();
        let timer;
        try {
            timer = timeout(this.options.timeout || 20000);
            const cp = this.transport.connect(srv, this.options);
            await Promise.race([
                cp,
                timer
            ]);
            (async ()=>{
                try {
                    for await (const b of this.transport){
                        this.parser.parse(b);
                    }
                } catch (err) {
                    console.log("reader closed", err);
                }
            })().then();
        } catch (err) {
            pong.reject(err);
        }
        try {
            await Promise.race([
                timer,
                pong
            ]);
            if (timer) {
                timer.cancel();
            }
            this.connected = true;
            this.connectError = undefined;
            this.sendSubscriptions();
            this.connectedOnce = true;
            this.server.didConnect = true;
            this.server.reconnects = 0;
            this.flushPending();
            this.heartbeats.start();
        } catch (err) {
            if (timer) {
                timer.cancel();
            }
            await this.transport.close(err);
            throw err;
        }
    }
    async _doDial(srv) {
        const { resolve } = this.options;
        const alts = await srv.resolve({
            fn: getResolveFn(),
            debug: this.options.debug,
            randomize: !this.options.noRandomize,
            resolve
        });
        let lastErr = null;
        for (const a of alts){
            try {
                lastErr = null;
                this.dispatchStatus({
                    type: DebugEvents.Reconnecting,
                    data: a.toString()
                });
                await this.dial(a);
                return;
            } catch (err) {
                lastErr = err;
            }
        }
        throw lastErr;
    }
    dialLoop() {
        if (this.connectPromise === null) {
            this.connectPromise = this.dodialLoop();
            this.connectPromise.then(()=>{}).catch(()=>{}).finally(()=>{
                this.connectPromise = null;
            });
        }
        return this.connectPromise;
    }
    async dodialLoop() {
        let lastError;
        while(true){
            if (this._closed) {
                this.servers.clear();
            }
            const wait = this.options.reconnectDelayHandler ? this.options.reconnectDelayHandler() : DEFAULT_RECONNECT_TIME_WAIT;
            let maxWait = wait;
            const srv = this.selectServer();
            if (!srv || this.abortReconnect) {
                if (lastError) {
                    throw lastError;
                } else if (this.lastError) {
                    throw this.lastError;
                } else {
                    throw NatsError.errorForCode(ErrorCode.ConnectionRefused);
                }
            }
            const now = Date.now();
            if (srv.lastConnect === 0 || srv.lastConnect + wait <= now) {
                srv.lastConnect = Date.now();
                try {
                    await this._doDial(srv);
                    break;
                } catch (err) {
                    lastError = err;
                    if (!this.connectedOnce) {
                        if (this.options.waitOnFirstConnect) {
                            continue;
                        }
                        this.servers.removeCurrentServer();
                    }
                    srv.reconnects++;
                    const mra = this.options.maxReconnectAttempts || 0;
                    if (mra !== -1 && srv.reconnects >= mra) {
                        this.servers.removeCurrentServer();
                    }
                }
            } else {
                maxWait = Math.min(maxWait, srv.lastConnect + wait - now);
                await delay(maxWait);
            }
        }
    }
    static async connect(options, publisher) {
        const h = new ProtocolHandler(options, publisher);
        await h.dialLoop();
        return h;
    }
    static toError(s) {
        const t = s ? s.toLowerCase() : "";
        if (t.indexOf("permissions violation") !== -1) {
            const err = new NatsError(s, ErrorCode.PermissionsViolation);
            const m = s.match(/(Publish|Subscription) to "(\S+)"/);
            if (m) {
                err.permissionContext = {
                    operation: m[1].toLowerCase(),
                    subject: m[2],
                    queue: undefined
                };
                const qm = s.match(/using queue "(\S+)"/);
                if (qm) {
                    err.permissionContext.queue = qm[1];
                }
            }
            return err;
        } else if (t.indexOf("authorization violation") !== -1) {
            return new NatsError(s, ErrorCode.AuthorizationViolation);
        } else if (t.indexOf("user authentication expired") !== -1) {
            return new NatsError(s, ErrorCode.AuthenticationExpired);
        } else if (t.indexOf("account authentication expired") != -1) {
            return new NatsError(s, ErrorCode.AccountExpired);
        } else if (t.indexOf("authentication timeout") !== -1) {
            return new NatsError(s, ErrorCode.AuthenticationTimeout);
        } else {
            return new NatsError(s, ErrorCode.ProtocolError);
        }
    }
    processMsg(msg, data) {
        this.inMsgs++;
        this.inBytes += data.length;
        if (!this.subscriptions.sidCounter) {
            return;
        }
        const sub = this.subscriptions.get(msg.sid);
        if (!sub) {
            return;
        }
        sub.received += 1;
        if (sub.callback) {
            sub.callback(null, new MsgImpl(msg, data, this));
        }
        if (sub.max !== undefined && sub.received >= sub.max) {
            sub.unsubscribe();
        }
    }
    processError(m) {
        const s = decode(m);
        const err = ProtocolHandler.toError(s);
        const status = {
            type: Events.Error,
            data: err.code
        };
        if (err.isPermissionError()) {
            let isMuxPermissionError = false;
            if (err.permissionContext) {
                status.permissionContext = err.permissionContext;
                const mux = this.subscriptions.getMux();
                isMuxPermissionError = mux?.subject === err.permissionContext.subject;
            }
            this.subscriptions.handleError(err);
            this.muxSubscriptions.handleError(isMuxPermissionError, err);
            if (isMuxPermissionError) {
                this.subscriptions.setMux(null);
            }
        }
        this.dispatchStatus(status);
        this.handleError(err);
    }
    handleError(err) {
        if (err.isAuthError()) {
            this.handleAuthError(err);
        } else if (err.isProtocolError()) {
            this.lastError = err;
        } else if (err.isAuthTimeout()) {
            this.lastError = err;
        }
        if (!err.isPermissionError()) {
            this.lastError = err;
        }
    }
    handleAuthError(err) {
        if (this.lastError && err.code === this.lastError.code && this.options.ignoreAuthErrorAbort === false) {
            this.abortReconnect = true;
        }
        if (this.connectError) {
            this.connectError(err);
        } else {
            this.disconnect();
        }
    }
    processPing() {
        this.transport.send(PONG_CMD);
    }
    processPong() {
        const cb = this.pongs.shift();
        if (cb) {
            cb.resolve();
        }
    }
    processInfo(m) {
        const info = JSON.parse(decode(m));
        this.info = info;
        const updates = this.options && this.options.ignoreClusterUpdates ? undefined : this.servers.update(info, this.transport.isEncrypted());
        if (!this.infoReceived) {
            this.features.update(parseSemVer(info.version));
            this.infoReceived = true;
            if (this.transport.isEncrypted()) {
                this.servers.updateTLSName();
            }
            const { version, lang } = this.transport;
            try {
                const c = new Connect({
                    version,
                    lang
                }, this.options, info.nonce);
                if (info.headers) {
                    c.headers = true;
                    c.no_responders = true;
                }
                const cs = JSON.stringify(c);
                this.transport.send(encode(`CONNECT ${cs}${CR_LF}`));
                this.transport.send(PING_CMD);
            } catch (err) {
                this._close(err);
            }
        }
        if (updates) {
            this.dispatchStatus({
                type: Events.Update,
                data: updates
            });
        }
        const ldm = info.ldm !== undefined ? info.ldm : false;
        if (ldm) {
            this.dispatchStatus({
                type: Events.LDM,
                data: this.servers.getCurrentServer().toString()
            });
        }
    }
    push(e) {
        switch(e.kind){
            case Kind.MSG:
                {
                    const { msg, data } = e;
                    this.processMsg(msg, data);
                    break;
                }
            case Kind.OK:
                break;
            case Kind.ERR:
                this.processError(e.data);
                break;
            case Kind.PING:
                this.processPing();
                break;
            case Kind.PONG:
                this.processPong();
                break;
            case Kind.INFO:
                this.processInfo(e.data);
                break;
        }
    }
    sendCommand(cmd, ...payloads) {
        const len = this.outbound.length();
        let buf;
        if (typeof cmd === "string") {
            buf = encode(cmd);
        } else {
            buf = cmd;
        }
        this.outbound.fill(buf, ...payloads);
        if (len === 0) {
            queueMicrotask(()=>{
                this.flushPending();
            });
        } else if (this.outbound.size() >= this.pendingLimit) {
            this.flushPending();
        }
    }
    publish(subject, payload = Empty, options) {
        let data;
        if (payload instanceof Uint8Array) {
            data = payload;
        } else if (typeof payload === "string") {
            data = TE.encode(payload);
        } else {
            throw NatsError.errorForCode(ErrorCode.BadPayload);
        }
        let len = data.length;
        options = options || {};
        options.reply = options.reply || "";
        let headers = Empty;
        let hlen = 0;
        if (options.headers) {
            if (this.info && !this.info.headers) {
                throw new NatsError("headers", ErrorCode.ServerOptionNotAvailable);
            }
            const hdrs = options.headers;
            headers = hdrs.encode();
            hlen = headers.length;
            len = data.length + hlen;
        }
        if (this.info && len > this.info.max_payload) {
            throw NatsError.errorForCode(ErrorCode.MaxPayloadExceeded);
        }
        this.outBytes += len;
        this.outMsgs++;
        let proto;
        if (options.headers) {
            if (options.reply) {
                proto = `HPUB ${subject} ${options.reply} ${hlen} ${len}\r\n`;
            } else {
                proto = `HPUB ${subject} ${hlen} ${len}\r\n`;
            }
            this.sendCommand(proto, headers, data, CRLF);
        } else {
            if (options.reply) {
                proto = `PUB ${subject} ${options.reply} ${len}\r\n`;
            } else {
                proto = `PUB ${subject} ${len}\r\n`;
            }
            this.sendCommand(proto, data, CRLF);
        }
    }
    request(r) {
        this.initMux();
        this.muxSubscriptions.add(r);
        return r;
    }
    subscribe(s) {
        this.subscriptions.add(s);
        this._subunsub(s);
        return s;
    }
    _sub(s) {
        if (s.queue) {
            this.sendCommand(`SUB ${s.subject} ${s.queue} ${s.sid}\r\n`);
        } else {
            this.sendCommand(`SUB ${s.subject} ${s.sid}\r\n`);
        }
    }
    _subunsub(s) {
        this._sub(s);
        if (s.max) {
            this.unsubscribe(s, s.max);
        }
        return s;
    }
    unsubscribe(s, max) {
        this.unsub(s, max);
        if (s.max === undefined || s.received >= s.max) {
            this.subscriptions.cancel(s);
        }
    }
    unsub(s, max) {
        if (!s || this.isClosed()) {
            return;
        }
        if (max) {
            this.sendCommand(`UNSUB ${s.sid} ${max}\r\n`);
        } else {
            this.sendCommand(`UNSUB ${s.sid}\r\n`);
        }
        s.max = max;
    }
    resub(s, subject) {
        if (!s || this.isClosed()) {
            return;
        }
        this.unsub(s);
        s.subject = subject;
        this.subscriptions.resub(s);
        this._sub(s);
    }
    flush(p) {
        if (!p) {
            p = deferred();
        }
        this.pongs.push(p);
        this.outbound.fill(PING_CMD);
        this.flushPending();
        return p;
    }
    sendSubscriptions() {
        const cmds = [];
        this.subscriptions.all().forEach((s)=>{
            const sub = s;
            if (sub.queue) {
                cmds.push(`SUB ${sub.subject} ${sub.queue} ${sub.sid}${CR_LF}`);
            } else {
                cmds.push(`SUB ${sub.subject} ${sub.sid}${CR_LF}`);
            }
        });
        if (cmds.length) {
            this.transport.send(encode(cmds.join("")));
        }
    }
    async _close(err) {
        if (this._closed) {
            return;
        }
        this.whyClosed = new Error("close trace").stack || "";
        this.heartbeats.cancel();
        if (this.connectError) {
            this.connectError(err);
            this.connectError = undefined;
        }
        this.muxSubscriptions.close();
        this.subscriptions.close();
        this.listeners.forEach((l)=>{
            l.stop();
        });
        this._closed = true;
        await this.transport.close(err);
        await this.closed.resolve(err);
    }
    close() {
        return this._close();
    }
    isClosed() {
        return this._closed;
    }
    drain() {
        const subs = this.subscriptions.all();
        const promises = [];
        subs.forEach((sub)=>{
            promises.push(sub.drain());
        });
        return Promise.all(promises).then(async ()=>{
            this.noMorePublishing = true;
            await this.flush();
            return this.close();
        }).catch(()=>{});
    }
    flushPending() {
        if (!this.infoReceived || !this.connected) {
            return;
        }
        if (this.outbound.size()) {
            const d = this.outbound.drain();
            this.transport.send(d);
        }
    }
    initMux() {
        const mux = this.subscriptions.getMux();
        if (!mux) {
            const inbox = this.muxSubscriptions.init(this.options.inboxPrefix);
            const sub = new SubscriptionImpl(this, `${inbox}*`);
            sub.callback = this.muxSubscriptions.dispatcher();
            this.subscriptions.setMux(sub);
            this.subscribe(sub);
        }
    }
    selectServer() {
        const server = this.servers.selectServer();
        if (server === undefined) {
            return undefined;
        }
        this.server = server;
        return this.server;
    }
    getServer() {
        return this.server;
    }
}
const ServiceApiPrefix = "$SRV";
class ServiceMsgImpl {
    msg;
    constructor(msg){
        this.msg = msg;
    }
    get data() {
        return this.msg.data;
    }
    get sid() {
        return this.msg.sid;
    }
    get subject() {
        return this.msg.subject;
    }
    get reply() {
        return this.msg.reply || "";
    }
    get headers() {
        return this.msg.headers;
    }
    respond(data, opts) {
        return this.msg.respond(data, opts);
    }
    respondError(code, description, data, opts) {
        opts = opts || {};
        opts.headers = opts.headers || headers();
        opts.headers?.set(ServiceErrorCodeHeader, `${code}`);
        opts.headers?.set(ServiceErrorHeader, description);
        return this.msg.respond(data, opts);
    }
    json(reviver) {
        return this.msg.json(reviver);
    }
    string() {
        return this.msg.string();
    }
}
class ServiceGroupImpl {
    subject;
    queue;
    srv;
    constructor(parent, name = "", queue = ""){
        if (name !== "") {
            validInternalToken("service group", name);
        }
        let root = "";
        if (parent instanceof ServiceImpl) {
            this.srv = parent;
            root = "";
        } else if (parent instanceof ServiceGroupImpl) {
            const sg = parent;
            this.srv = sg.srv;
            if (queue === "" && sg.queue !== "") {
                queue = sg.queue;
            }
            root = sg.subject;
        } else {
            throw new Error("unknown ServiceGroup type");
        }
        this.subject = this.calcSubject(root, name);
        this.queue = queue;
    }
    calcSubject(root, name = "") {
        if (name === "") {
            return root;
        }
        return root !== "" ? `${root}.${name}` : name;
    }
    addEndpoint(name = "", opts) {
        opts = opts || {
            subject: name
        };
        const args = typeof opts === "function" ? {
            handler: opts,
            subject: name
        } : opts;
        validateName("endpoint", name);
        let { subject, handler, metadata, queue } = args;
        subject = subject || name;
        queue = queue || this.queue;
        validSubjectName("endpoint subject", subject);
        subject = this.calcSubject(this.subject, subject);
        const ne = {
            name,
            subject,
            queue,
            handler,
            metadata
        };
        return this.srv._addEndpoint(ne);
    }
    addGroup(name = "", queue = "") {
        return new ServiceGroupImpl(this, name, queue);
    }
}
function validSubjectName(context, subj) {
    if (subj === "") {
        throw new Error(`${context} cannot be empty`);
    }
    if (subj.indexOf(" ") !== -1) {
        throw new Error(`${context} cannot contain spaces: '${subj}'`);
    }
    const tokens = subj.split(".");
    tokens.forEach((v, idx)=>{
        if (v === ">" && idx !== tokens.length - 1) {
            throw new Error(`${context} cannot have internal '>': '${subj}'`);
        }
    });
}
function validInternalToken(context, subj) {
    if (subj.indexOf(" ") !== -1) {
        throw new Error(`${context} cannot contain spaces: '${subj}'`);
    }
    const tokens = subj.split(".");
    tokens.forEach((v)=>{
        if (v === ">") {
            throw new Error(`${context} name cannot contain internal '>': '${subj}'`);
        }
    });
}
class ServiceImpl {
    nc;
    _id;
    config;
    handlers;
    internal;
    _stopped;
    _done;
    started;
    static controlSubject(verb, name = "", id = "", prefix) {
        const pre = prefix ?? ServiceApiPrefix;
        if (name === "" && id === "") {
            return `${pre}.${verb}`;
        }
        validateName("control subject name", name);
        if (id !== "") {
            validateName("control subject id", id);
            return `${pre}.${verb}.${name}.${id}`;
        }
        return `${pre}.${verb}.${name}`;
    }
    constructor(nc, config = {
        name: "",
        version: ""
    }){
        this.nc = nc;
        this.config = Object.assign({}, config);
        if (!this.config.queue) {
            this.config.queue = "q";
        }
        validateName("name", this.config.name);
        validateName("queue", this.config.queue);
        parseSemVer(this.config.version);
        this._id = nuid.next();
        this.internal = [];
        this._done = deferred();
        this._stopped = false;
        this.handlers = [];
        this.started = new Date().toISOString();
        this.reset();
        this.nc.closed().then(()=>{
            this.close().catch();
        }).catch((err)=>{
            this.close(err).catch();
        });
    }
    get subjects() {
        return this.handlers.filter((s)=>{
            return s.internal === false;
        }).map((s)=>{
            return s.subject;
        });
    }
    get id() {
        return this._id;
    }
    get name() {
        return this.config.name;
    }
    get description() {
        return this.config.description ?? "";
    }
    get version() {
        return this.config.version;
    }
    get metadata() {
        return this.config.metadata;
    }
    errorToHeader(err) {
        const h = headers();
        if (err instanceof ServiceError) {
            const se = err;
            h.set(ServiceErrorHeader, se.message);
            h.set(ServiceErrorCodeHeader, `${se.code}`);
        } else {
            h.set(ServiceErrorHeader, err.message);
            h.set(ServiceErrorCodeHeader, "500");
        }
        return h;
    }
    setupHandler(h, internal = false) {
        const queue = internal ? "" : h.queue ? h.queue : this.config.queue;
        const { name, subject, handler } = h;
        const sv = h;
        sv.internal = internal;
        if (internal) {
            this.internal.push(sv);
        }
        sv.stats = new NamedEndpointStatsImpl(name, subject, queue);
        sv.queue = queue;
        const callback = handler ? (err, msg)=>{
            if (err) {
                this.close(err);
                return;
            }
            const start = Date.now();
            try {
                handler(err, new ServiceMsgImpl(msg));
            } catch (err) {
                sv.stats.countError(err);
                msg?.respond(Empty, {
                    headers: this.errorToHeader(err)
                });
            } finally{
                sv.stats.countLatency(start);
            }
        } : undefined;
        sv.sub = this.nc.subscribe(subject, {
            callback,
            queue
        });
        sv.sub.closed.then(()=>{
            if (!this._stopped) {
                this.close(new Error(`required subscription ${h.subject} stopped`)).catch();
            }
        }).catch((err)=>{
            if (!this._stopped) {
                const ne = new Error(`required subscription ${h.subject} errored: ${err.message}`);
                ne.stack = err.stack;
                this.close(ne).catch();
            }
        });
        return sv;
    }
    info() {
        return {
            type: ServiceResponseType.INFO,
            name: this.name,
            id: this.id,
            version: this.version,
            description: this.description,
            metadata: this.metadata,
            endpoints: this.endpoints()
        };
    }
    endpoints() {
        return this.handlers.map((v)=>{
            const { subject, metadata, name, queue } = v;
            return {
                subject,
                metadata,
                name,
                queue_group: queue
            };
        });
    }
    async stats() {
        const endpoints = [];
        for (const h of this.handlers){
            if (typeof this.config.statsHandler === "function") {
                try {
                    h.stats.data = await this.config.statsHandler(h);
                } catch (err) {
                    h.stats.countError(err);
                }
            }
            endpoints.push(h.stats.stats(h.qi));
        }
        return {
            type: ServiceResponseType.STATS,
            name: this.name,
            id: this.id,
            version: this.version,
            started: this.started,
            metadata: this.metadata,
            endpoints
        };
    }
    addInternalHandler(verb, handler) {
        const v = `${verb}`.toUpperCase();
        this._doAddInternalHandler(`${v}-all`, verb, handler);
        this._doAddInternalHandler(`${v}-kind`, verb, handler, this.name);
        this._doAddInternalHandler(`${v}`, verb, handler, this.name, this.id);
    }
    _doAddInternalHandler(name, verb, handler, kind = "", id = "") {
        const endpoint = {};
        endpoint.name = name;
        endpoint.subject = ServiceImpl.controlSubject(verb, kind, id);
        endpoint.handler = handler;
        this.setupHandler(endpoint, true);
    }
    start() {
        const jc = JSONCodec();
        const statsHandler = (err, msg)=>{
            if (err) {
                this.close(err);
                return Promise.reject(err);
            }
            return this.stats().then((s)=>{
                msg?.respond(jc.encode(s));
                return Promise.resolve();
            });
        };
        const infoHandler = (err, msg)=>{
            if (err) {
                this.close(err);
                return Promise.reject(err);
            }
            msg?.respond(jc.encode(this.info()));
            return Promise.resolve();
        };
        const ping = jc.encode(this.ping());
        const pingHandler = (err, msg)=>{
            if (err) {
                this.close(err).then().catch();
                return Promise.reject(err);
            }
            msg.respond(ping);
            return Promise.resolve();
        };
        this.addInternalHandler(ServiceVerb.PING, pingHandler);
        this.addInternalHandler(ServiceVerb.STATS, statsHandler);
        this.addInternalHandler(ServiceVerb.INFO, infoHandler);
        this.handlers.forEach((h)=>{
            const { subject } = h;
            if (typeof subject !== "string") {
                return;
            }
            if (h.handler === null) {
                return;
            }
            this.setupHandler(h);
        });
        return Promise.resolve(this);
    }
    close(err) {
        if (this._stopped) {
            return this._done;
        }
        this._stopped = true;
        let buf = [];
        if (!this.nc.isClosed()) {
            buf = this.handlers.concat(this.internal).map((h)=>{
                return h.sub.drain();
            });
        }
        Promise.allSettled(buf).then(()=>{
            this._done.resolve(err ? err : null);
        });
        return this._done;
    }
    get stopped() {
        return this._done;
    }
    get isStopped() {
        return this._stopped;
    }
    stop(err) {
        return this.close(err);
    }
    ping() {
        return {
            type: ServiceResponseType.PING,
            name: this.name,
            id: this.id,
            version: this.version,
            metadata: this.metadata
        };
    }
    reset() {
        this.started = new Date().toISOString();
        if (this.handlers) {
            for (const h of this.handlers){
                h.stats.reset(h.qi);
            }
        }
    }
    addGroup(name, queue) {
        return new ServiceGroupImpl(this, name, queue);
    }
    addEndpoint(name, handler) {
        const sg = new ServiceGroupImpl(this);
        return sg.addEndpoint(name, handler);
    }
    _addEndpoint(e) {
        const qi = new QueuedIteratorImpl();
        qi.noIterator = typeof e.handler === "function";
        if (!qi.noIterator) {
            e.handler = (err, msg)=>{
                err ? this.stop(err).catch() : qi.push(new ServiceMsgImpl(msg));
            };
            qi.iterClosed.then(()=>{
                this.close().catch();
            });
        }
        const ss = this.setupHandler(e, false);
        ss.qi = qi;
        this.handlers.push(ss);
        return qi;
    }
}
class NamedEndpointStatsImpl {
    name;
    subject;
    average_processing_time;
    num_requests;
    processing_time;
    num_errors;
    last_error;
    data;
    metadata;
    queue;
    constructor(name, subject, queue = ""){
        this.name = name;
        this.subject = subject;
        this.average_processing_time = 0;
        this.num_errors = 0;
        this.num_requests = 0;
        this.processing_time = 0;
        this.queue = queue;
    }
    reset(qi) {
        this.num_requests = 0;
        this.processing_time = 0;
        this.average_processing_time = 0;
        this.num_errors = 0;
        this.last_error = undefined;
        this.data = undefined;
        const qii = qi;
        if (qii) {
            qii.time = 0;
            qii.processed = 0;
        }
    }
    countLatency(start) {
        this.num_requests++;
        this.processing_time += nanos(Date.now() - start);
        this.average_processing_time = Math.round(this.processing_time / this.num_requests);
    }
    countError(err) {
        this.num_errors++;
        this.last_error = err.message;
    }
    _stats() {
        const { name, subject, average_processing_time, num_errors, num_requests, processing_time, last_error, data, queue } = this;
        return {
            name,
            subject,
            average_processing_time,
            num_errors,
            num_requests,
            processing_time,
            last_error,
            data,
            queue_group: queue
        };
    }
    stats(qi) {
        const qii = qi;
        if (qii?.noIterator === false) {
            this.processing_time = nanos(qii.time);
            this.num_requests = qii.processed;
            this.average_processing_time = this.processing_time > 0 && this.num_requests > 0 ? this.processing_time / this.num_requests : 0;
        }
        return this._stats();
    }
}
class ServiceClientImpl {
    nc;
    prefix;
    opts;
    constructor(nc, opts = {
        strategy: RequestStrategy.JitterTimer,
        maxWait: 2000
    }, prefix){
        this.nc = nc;
        this.prefix = prefix;
        this.opts = opts;
    }
    ping(name = "", id = "") {
        return this.q(ServiceVerb.PING, name, id);
    }
    stats(name = "", id = "") {
        return this.q(ServiceVerb.STATS, name, id);
    }
    info(name = "", id = "") {
        return this.q(ServiceVerb.INFO, name, id);
    }
    async q(v, name = "", id = "") {
        const iter = new QueuedIteratorImpl();
        const jc = JSONCodec();
        const subj = ServiceImpl.controlSubject(v, name, id, this.prefix);
        const responses = await this.nc.requestMany(subj, Empty, this.opts);
        (async ()=>{
            for await (const m of responses){
                try {
                    const s = jc.decode(m.data);
                    iter.push(s);
                } catch (err) {
                    iter.push(()=>{
                        iter.stop(err);
                    });
                }
            }
            iter.push(()=>{
                iter.stop();
            });
        })().catch((err)=>{
            iter.stop(err);
        });
        return iter;
    }
}
class Metric {
    name;
    duration;
    date;
    payload;
    msgs;
    lang;
    version;
    bytes;
    asyncRequests;
    min;
    max;
    constructor(name, duration){
        this.name = name;
        this.duration = duration;
        this.date = Date.now();
        this.payload = 0;
        this.msgs = 0;
        this.bytes = 0;
    }
    toString() {
        const sec = this.duration / 1000;
        const mps = Math.round(this.msgs / sec);
        const label = this.asyncRequests ? "asyncRequests" : "";
        let minmax = "";
        if (this.max) {
            minmax = `${this.min}/${this.max}`;
        }
        return `${this.name}${label ? " [asyncRequests]" : ""} ${humanizeNumber(mps)} msgs/sec - [${sec.toFixed(2)} secs] ~ ${throughput(this.bytes, sec)} ${minmax}`;
    }
    toCsv() {
        return `"${this.name}",${new Date(this.date).toISOString()},${this.lang},${this.version},${this.msgs},${this.payload},${this.bytes},${this.duration},${this.asyncRequests ? this.asyncRequests : false}\n`;
    }
    static header() {
        return `Test,Date,Lang,Version,Count,MsgPayload,Bytes,Millis,Async\n`;
    }
}
class Bench {
    nc;
    callbacks;
    msgs;
    size;
    subject;
    asyncRequests;
    pub;
    sub;
    req;
    rep;
    perf;
    payload;
    constructor(nc, opts = {
        msgs: 100000,
        size: 128,
        subject: "",
        asyncRequests: false,
        pub: false,
        sub: false,
        req: false,
        rep: false
    }){
        this.nc = nc;
        this.callbacks = opts.callbacks || false;
        this.msgs = opts.msgs || 0;
        this.size = opts.size || 0;
        this.subject = opts.subject || nuid.next();
        this.asyncRequests = opts.asyncRequests || false;
        this.pub = opts.pub || false;
        this.sub = opts.sub || false;
        this.req = opts.req || false;
        this.rep = opts.rep || false;
        this.perf = new Perf();
        this.payload = this.size ? new Uint8Array(this.size) : Empty;
        if (!this.pub && !this.sub && !this.req && !this.rep) {
            throw new Error("no bench option selected");
        }
    }
    async run() {
        this.nc.closed().then((err)=>{
            if (err) {
                throw new NatsError(`bench closed with an error: ${err.message}`, ErrorCode.Unknown, err);
            }
        });
        if (this.callbacks) {
            await this.runCallbacks();
        } else {
            await this.runAsync();
        }
        return this.processMetrics();
    }
    processMetrics() {
        const nc = this.nc;
        const { lang, version } = nc.protocol.transport;
        if (this.pub && this.sub) {
            this.perf.measure("pubsub", "pubStart", "subStop");
        }
        if (this.req && this.rep) {
            this.perf.measure("reqrep", "reqStart", "reqStop");
        }
        const measures = this.perf.getEntries();
        const pubsub = measures.find((m)=>m.name === "pubsub");
        const reqrep = measures.find((m)=>m.name === "reqrep");
        const req = measures.find((m)=>m.name === "req");
        const rep = measures.find((m)=>m.name === "rep");
        const pub = measures.find((m)=>m.name === "pub");
        const sub = measures.find((m)=>m.name === "sub");
        const stats = this.nc.stats();
        const metrics = [];
        if (pubsub) {
            const { name, duration } = pubsub;
            const m = new Metric(name, duration);
            m.msgs = this.msgs * 2;
            m.bytes = stats.inBytes + stats.outBytes;
            m.lang = lang;
            m.version = version;
            m.payload = this.payload.length;
            metrics.push(m);
        }
        if (reqrep) {
            const { name, duration } = reqrep;
            const m = new Metric(name, duration);
            m.msgs = this.msgs * 2;
            m.bytes = stats.inBytes + stats.outBytes;
            m.lang = lang;
            m.version = version;
            m.payload = this.payload.length;
            metrics.push(m);
        }
        if (pub) {
            const { name, duration } = pub;
            const m = new Metric(name, duration);
            m.msgs = this.msgs;
            m.bytes = stats.outBytes;
            m.lang = lang;
            m.version = version;
            m.payload = this.payload.length;
            metrics.push(m);
        }
        if (sub) {
            const { name, duration } = sub;
            const m = new Metric(name, duration);
            m.msgs = this.msgs;
            m.bytes = stats.inBytes;
            m.lang = lang;
            m.version = version;
            m.payload = this.payload.length;
            metrics.push(m);
        }
        if (rep) {
            const { name, duration } = rep;
            const m = new Metric(name, duration);
            m.msgs = this.msgs;
            m.bytes = stats.inBytes + stats.outBytes;
            m.lang = lang;
            m.version = version;
            m.payload = this.payload.length;
            metrics.push(m);
        }
        if (req) {
            const { name, duration } = req;
            const m = new Metric(name, duration);
            m.msgs = this.msgs;
            m.bytes = stats.inBytes + stats.outBytes;
            m.lang = lang;
            m.version = version;
            m.payload = this.payload.length;
            metrics.push(m);
        }
        return metrics;
    }
    async runCallbacks() {
        const jobs = [];
        if (this.sub) {
            const d = deferred();
            jobs.push(d);
            let i = 0;
            this.nc.subscribe(this.subject, {
                max: this.msgs,
                callback: ()=>{
                    i++;
                    if (i === 1) {
                        this.perf.mark("subStart");
                    }
                    if (i === this.msgs) {
                        this.perf.mark("subStop");
                        this.perf.measure("sub", "subStart", "subStop");
                        d.resolve();
                    }
                }
            });
        }
        if (this.rep) {
            const d = deferred();
            jobs.push(d);
            let i = 0;
            this.nc.subscribe(this.subject, {
                max: this.msgs,
                callback: (_, m)=>{
                    m.respond(this.payload);
                    i++;
                    if (i === 1) {
                        this.perf.mark("repStart");
                    }
                    if (i === this.msgs) {
                        this.perf.mark("repStop");
                        this.perf.measure("rep", "repStart", "repStop");
                        d.resolve();
                    }
                }
            });
        }
        if (this.pub) {
            const job = (async ()=>{
                this.perf.mark("pubStart");
                for(let i = 0; i < this.msgs; i++){
                    this.nc.publish(this.subject, this.payload);
                }
                await this.nc.flush();
                this.perf.mark("pubStop");
                this.perf.measure("pub", "pubStart", "pubStop");
            })();
            jobs.push(job);
        }
        if (this.req) {
            const job = (async ()=>{
                if (this.asyncRequests) {
                    this.perf.mark("reqStart");
                    const a = [];
                    for(let i = 0; i < this.msgs; i++){
                        a.push(this.nc.request(this.subject, this.payload, {
                            timeout: 20000
                        }));
                    }
                    await Promise.all(a);
                    this.perf.mark("reqStop");
                    this.perf.measure("req", "reqStart", "reqStop");
                } else {
                    this.perf.mark("reqStart");
                    for(let i = 0; i < this.msgs; i++){
                        await this.nc.request(this.subject);
                    }
                    this.perf.mark("reqStop");
                    this.perf.measure("req", "reqStart", "reqStop");
                }
            })();
            jobs.push(job);
        }
        await Promise.all(jobs);
    }
    async runAsync() {
        const jobs = [];
        if (this.rep) {
            let first = false;
            const sub = this.nc.subscribe(this.subject, {
                max: this.msgs
            });
            const job = (async ()=>{
                for await (const m of sub){
                    if (!first) {
                        this.perf.mark("repStart");
                        first = true;
                    }
                    m.respond(this.payload);
                }
                await this.nc.flush();
                this.perf.mark("repStop");
                this.perf.measure("rep", "repStart", "repStop");
            })();
            jobs.push(job);
        }
        if (this.sub) {
            let first = false;
            const sub = this.nc.subscribe(this.subject, {
                max: this.msgs
            });
            const job = (async ()=>{
                for await (const _m of sub){
                    if (!first) {
                        this.perf.mark("subStart");
                        first = true;
                    }
                }
                this.perf.mark("subStop");
                this.perf.measure("sub", "subStart", "subStop");
            })();
            jobs.push(job);
        }
        if (this.pub) {
            const job = (async ()=>{
                this.perf.mark("pubStart");
                for(let i = 0; i < this.msgs; i++){
                    this.nc.publish(this.subject, this.payload);
                }
                await this.nc.flush();
                this.perf.mark("pubStop");
                this.perf.measure("pub", "pubStart", "pubStop");
            })();
            jobs.push(job);
        }
        if (this.req) {
            const job = (async ()=>{
                if (this.asyncRequests) {
                    this.perf.mark("reqStart");
                    const a = [];
                    for(let i = 0; i < this.msgs; i++){
                        a.push(this.nc.request(this.subject, this.payload, {
                            timeout: 20000
                        }));
                    }
                    await Promise.all(a);
                    this.perf.mark("reqStop");
                    this.perf.measure("req", "reqStart", "reqStop");
                } else {
                    this.perf.mark("reqStart");
                    for(let i = 0; i < this.msgs; i++){
                        await this.nc.request(this.subject);
                    }
                    this.perf.mark("reqStop");
                    this.perf.measure("req", "reqStart", "reqStop");
                }
            })();
            jobs.push(job);
        }
        await Promise.all(jobs);
    }
}
function throughput(bytes, seconds) {
    return `${humanizeBytes(bytes / seconds)}/sec`;
}
function humanizeBytes(bytes, si = false) {
    const base = si ? 1000 : 1024;
    const pre = si ? [
        "k",
        "M",
        "G",
        "T",
        "P",
        "E"
    ] : [
        "K",
        "M",
        "G",
        "T",
        "P",
        "E"
    ];
    const post = si ? "iB" : "B";
    if (bytes < base) {
        return `${bytes.toFixed(2)} ${post}`;
    }
    const exp = parseInt(Math.log(bytes) / Math.log(base) + "");
    const index = parseInt(exp - 1 + "");
    return `${(bytes / Math.pow(base, exp)).toFixed(2)} ${pre[index]}${post}`;
}
function humanizeNumber(n) {
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}
export { backoff as backoff, Bench as Bench, buildAuthenticator as buildAuthenticator, canonicalMIMEHeaderKey as canonicalMIMEHeaderKey, createInbox as createInbox, credsAuthenticator as credsAuthenticator, deadline as deadline, DebugEvents as DebugEvents, deferred as deferred, delay as delay, Empty as Empty, ErrorCode as ErrorCode, Events as Events, headers as headers, JSONCodec as JSONCodec, jwtAuthenticator as jwtAuthenticator, Match as Match, Metric as Metric, millis as millis, MsgHdrsImpl as MsgHdrsImpl, nanos as nanos, NatsError as NatsError, nkeyAuthenticator as nkeyAuthenticator, mod as nkeys, Nuid as Nuid, nuid as nuid, RequestStrategy as RequestStrategy, ServiceError as ServiceError, ServiceErrorCodeHeader as ServiceErrorCodeHeader, ServiceErrorHeader as ServiceErrorHeader, ServiceResponseType as ServiceResponseType, ServiceVerb as ServiceVerb, StringCodec as StringCodec, syncIterator as syncIterator, tokenAuthenticator as tokenAuthenticator, usernamePasswordAuthenticator as usernamePasswordAuthenticator };
function NoopKvCodecs() {
    return {
        key: {
            encode (k) {
                return k;
            },
            decode (k) {
                return k;
            }
        },
        value: {
            encode (v) {
                return v;
            },
            decode (v) {
                return v;
            }
        }
    };
}
function defaultBucketOpts() {
    return {
        replicas: 1,
        history: 1,
        timeout: 2000,
        max_bytes: -1,
        maxValueSize: -1,
        codec: NoopKvCodecs(),
        storage: StorageType.File
    };
}
const kvOperationHdr = "KV-Operation";
const kvSubjectPrefix = "$KV";
const validKeyRe = /^[-/=.\w]+$/;
const validSearchKey = /^[-/=.>*\w]+$/;
const validBucketRe = /^[-\w]+$/;
function validateKey(k) {
    if (k.startsWith(".") || k.endsWith(".") || !validKeyRe.test(k)) {
        throw new Error(`invalid key: ${k}`);
    }
}
function validateSearchKey(k) {
    if (k.startsWith(".") || k.endsWith(".") || !validSearchKey.test(k)) {
        throw new Error(`invalid key: ${k}`);
    }
}
function hasWildcards(k) {
    if (k.startsWith(".") || k.endsWith(".")) {
        throw new Error(`invalid key: ${k}`);
    }
    const chunks = k.split(".");
    let hasWildcards = false;
    for(let i = 0; i < chunks.length; i++){
        switch(chunks[i]){
            case "*":
                hasWildcards = true;
                break;
            case ">":
                if (i !== chunks.length - 1) {
                    throw new Error(`invalid key: ${k}`);
                }
                hasWildcards = true;
                break;
            default:
        }
    }
    return hasWildcards;
}
function validateBucket(name) {
    if (!validBucketRe.test(name)) {
        throw new Error(`invalid bucket name: ${name}`);
    }
}
var PubHeaders;
(function(PubHeaders) {
    PubHeaders["MsgIdHdr"] = "Nats-Msg-Id";
    PubHeaders["ExpectedStreamHdr"] = "Nats-Expected-Stream";
    PubHeaders["ExpectedLastSeqHdr"] = "Nats-Expected-Last-Sequence";
    PubHeaders["ExpectedLastMsgIdHdr"] = "Nats-Expected-Last-Msg-Id";
    PubHeaders["ExpectedLastSubjectSequenceHdr"] = "Nats-Expected-Last-Subject-Sequence";
})(PubHeaders || (PubHeaders = {}));
class Bucket {
    js;
    jsm;
    stream;
    bucket;
    direct;
    codec;
    prefix;
    editPrefix;
    useJsPrefix;
    _prefixLen;
    constructor(bucket, js, jsm){
        validateBucket(bucket);
        this.js = js;
        this.jsm = jsm;
        this.bucket = bucket;
        this.prefix = kvSubjectPrefix;
        this.editPrefix = "";
        this.useJsPrefix = false;
        this._prefixLen = 0;
    }
    static async create(js, name, opts = {}) {
        validateBucket(name);
        const jsm = await js.jetstreamManager();
        const bucket = new Bucket(name, js, jsm);
        await bucket.init(opts);
        return bucket;
    }
    static async bind(js, name, opts = {}) {
        const jsm = await js.jetstreamManager();
        const info = {
            config: {
                allow_direct: opts.allow_direct
            }
        };
        validateBucket(name);
        const bucket = new Bucket(name, js, jsm);
        info.config.name = opts.streamName ?? bucket.bucketName();
        Object.assign(bucket, info);
        bucket.stream = info.config.name;
        bucket.codec = opts.codec || NoopKvCodecs();
        bucket.direct = info.config.allow_direct ?? false;
        bucket.initializePrefixes(info);
        return bucket;
    }
    async init(opts = {}) {
        const bo = Object.assign(defaultBucketOpts(), opts);
        this.codec = bo.codec;
        const sc = {};
        this.stream = sc.name = opts.streamName ?? this.bucketName();
        sc.retention = RetentionPolicy.Limits;
        sc.max_msgs_per_subject = bo.history;
        if (bo.maxBucketSize) {
            bo.max_bytes = bo.maxBucketSize;
        }
        if (bo.max_bytes) {
            sc.max_bytes = bo.max_bytes;
        }
        sc.max_msg_size = bo.maxValueSize;
        sc.storage = bo.storage;
        const location = opts.placementCluster ?? "";
        if (location) {
            opts.placement = {};
            opts.placement.cluster = location;
            opts.placement.tags = [];
        }
        if (opts.placement) {
            sc.placement = opts.placement;
        }
        if (opts.republish) {
            sc.republish = opts.republish;
        }
        if (opts.description) {
            sc.description = opts.description;
        }
        if (opts.mirror) {
            const mirror = Object.assign({}, opts.mirror);
            if (!mirror.name.startsWith(kvPrefix)) {
                mirror.name = `${kvPrefix}${mirror.name}`;
            }
            sc.mirror = mirror;
            sc.mirror_direct = true;
        } else if (opts.sources) {
            const sources = opts.sources.map((s)=>{
                const c = Object.assign({}, s);
                const srcBucketName = c.name.startsWith(kvPrefix) ? c.name.substring(kvPrefix.length) : c.name;
                if (!c.name.startsWith(kvPrefix)) {
                    c.name = `${kvPrefix}${c.name}`;
                }
                if (!s.external && srcBucketName !== this.bucket) {
                    c.subject_transforms = [
                        {
                            src: `$KV.${srcBucketName}.>`,
                            dest: `$KV.${this.bucket}.>`
                        }
                    ];
                }
                return c;
            });
            sc.sources = sources;
            sc.subjects = [
                this.subjectForBucket()
            ];
        } else {
            sc.subjects = [
                this.subjectForBucket()
            ];
        }
        if (opts.metadata) {
            sc.metadata = opts.metadata;
        }
        if (typeof opts.compression === "boolean") {
            sc.compression = opts.compression ? StoreCompression.S2 : StoreCompression.None;
        }
        const nci = this.js.nc;
        const have = nci.getServerVersion();
        const discardNew = have ? compare(have, parseSemVer("2.7.2")) >= 0 : false;
        sc.discard = discardNew ? DiscardPolicy.New : DiscardPolicy.Old;
        const { ok: direct, min } = nci.features.get(Feature.JS_ALLOW_DIRECT);
        if (!direct && opts.allow_direct === true) {
            const v = have ? `${have.major}.${have.minor}.${have.micro}` : "unknown";
            return Promise.reject(new Error(`allow_direct is not available on server version ${v} - requires ${min}`));
        }
        opts.allow_direct = typeof opts.allow_direct === "boolean" ? opts.allow_direct : direct;
        sc.allow_direct = opts.allow_direct;
        this.direct = sc.allow_direct;
        sc.num_replicas = bo.replicas;
        if (bo.ttl) {
            sc.max_age = nanos(bo.ttl);
        }
        sc.allow_rollup_hdrs = true;
        let info;
        try {
            info = await this.jsm.streams.info(sc.name);
            if (!info.config.allow_direct && this.direct === true) {
                this.direct = false;
            }
        } catch (err) {
            if (err.message === "stream not found") {
                info = await this.jsm.streams.add(sc);
            } else {
                throw err;
            }
        }
        this.initializePrefixes(info);
    }
    initializePrefixes(info) {
        this._prefixLen = 0;
        this.prefix = `$KV.${this.bucket}`;
        this.useJsPrefix = this.js.apiPrefix !== "$JS.API";
        const { mirror } = info.config;
        if (mirror) {
            let n = mirror.name;
            if (n.startsWith(kvPrefix)) {
                n = n.substring(kvPrefix.length);
            }
            if (mirror.external && mirror.external.api !== "") {
                const mb = mirror.name.substring(kvPrefix.length);
                this.useJsPrefix = false;
                this.prefix = `$KV.${mb}`;
                this.editPrefix = `${mirror.external.api}.$KV.${n}`;
            } else {
                this.editPrefix = this.prefix;
            }
        }
    }
    bucketName() {
        return this.stream ?? `${kvPrefix}${this.bucket}`;
    }
    subjectForBucket() {
        return `${this.prefix}.${this.bucket}.>`;
    }
    subjectForKey(k, edit = false) {
        const builder = [];
        if (edit) {
            if (this.useJsPrefix) {
                builder.push(this.js.apiPrefix);
            }
            if (this.editPrefix !== "") {
                builder.push(this.editPrefix);
            } else {
                builder.push(this.prefix);
            }
        } else {
            if (this.prefix) {
                builder.push(this.prefix);
            }
        }
        builder.push(k);
        return builder.join(".");
    }
    fullKeyName(k) {
        if (this.prefix !== "") {
            return `${this.prefix}.${k}`;
        }
        return `${kvSubjectPrefix}.${this.bucket}.${k}`;
    }
    get prefixLen() {
        if (this._prefixLen === 0) {
            this._prefixLen = this.prefix.length + 1;
        }
        return this._prefixLen;
    }
    encodeKey(key) {
        const chunks = [];
        for (const t of key.split(".")){
            switch(t){
                case ">":
                case "*":
                    chunks.push(t);
                    break;
                default:
                    chunks.push(this.codec.key.encode(t));
                    break;
            }
        }
        return chunks.join(".");
    }
    decodeKey(ekey) {
        const chunks = [];
        for (const t of ekey.split(".")){
            switch(t){
                case ">":
                case "*":
                    chunks.push(t);
                    break;
                default:
                    chunks.push(this.codec.key.decode(t));
                    break;
            }
        }
        return chunks.join(".");
    }
    validateKey = validateKey;
    validateSearchKey = validateSearchKey;
    hasWildcards = hasWildcards;
    close() {
        return Promise.resolve();
    }
    dataLen(data, h) {
        const slen = h ? h.get(JsHeaders.MessageSizeHdr) || "" : "";
        if (slen !== "") {
            return parseInt(slen, 10);
        }
        return data.length;
    }
    smToEntry(sm) {
        return new KvStoredEntryImpl(this.bucket, this.prefixLen, sm);
    }
    jmToEntry(jm) {
        const key = this.decodeKey(jm.subject.substring(this.prefixLen));
        return new KvJsMsgEntryImpl(this.bucket, key, jm);
    }
    async create(k, data) {
        let firstErr;
        try {
            const n = await this.put(k, data, {
                previousSeq: 0
            });
            return Promise.resolve(n);
        } catch (err) {
            firstErr = err;
            if (err?.api_error?.err_code !== 10071) {
                return Promise.reject(err);
            }
        }
        let rev = 0;
        try {
            const e = await this.get(k);
            if (e?.operation === "DEL" || e?.operation === "PURGE") {
                rev = e !== null ? e.revision : 0;
                return this.update(k, data, rev);
            } else {
                return Promise.reject(firstErr);
            }
        } catch (err) {
            return Promise.reject(err);
        }
    }
    update(k, data, version) {
        if (version <= 0) {
            throw new Error("version must be greater than 0");
        }
        return this.put(k, data, {
            previousSeq: version
        });
    }
    async put(k, data, opts = {}) {
        const ek = this.encodeKey(k);
        this.validateKey(ek);
        const o = {};
        if (opts.previousSeq !== undefined) {
            const h = headers();
            o.headers = h;
            h.set(PubHeaders.ExpectedLastSubjectSequenceHdr, `${opts.previousSeq}`);
        }
        try {
            const pa = await this.js.publish(this.subjectForKey(ek, true), data, o);
            return pa.seq;
        } catch (err) {
            const ne = err;
            if (ne.isJetStreamError()) {
                ne.message = ne.api_error?.description;
                ne.code = `${ne.api_error?.code}`;
                return Promise.reject(ne);
            }
            return Promise.reject(err);
        }
    }
    async get(k, opts) {
        const ek = this.encodeKey(k);
        this.validateKey(ek);
        let arg = {
            last_by_subj: this.subjectForKey(ek)
        };
        if (opts && opts.revision > 0) {
            arg = {
                seq: opts.revision
            };
        }
        let sm;
        try {
            if (this.direct) {
                const direct = this.jsm.direct;
                sm = await direct.getMessage(this.bucketName(), arg);
            } else {
                sm = await this.jsm.streams.getMessage(this.bucketName(), arg);
            }
            const ke = this.smToEntry(sm);
            if (ke.key !== ek) {
                return null;
            }
            return ke;
        } catch (err) {
            if (err.code === ErrorCode.JetStream404NoMessages) {
                return null;
            }
            throw err;
        }
    }
    purge(k, opts) {
        return this._deleteOrPurge(k, "PURGE", opts);
    }
    delete(k, opts) {
        return this._deleteOrPurge(k, "DEL", opts);
    }
    async purgeDeletes(olderMillis = 30 * 60 * 1000) {
        const done = deferred();
        const buf = [];
        const i = await this.watch({
            key: ">",
            initializedFn: ()=>{
                done.resolve();
            }
        });
        (async ()=>{
            for await (const e of i){
                if (e.operation === "DEL" || e.operation === "PURGE") {
                    buf.push(e);
                }
            }
        })().then();
        await done;
        i.stop();
        const min = Date.now() - olderMillis;
        const proms = buf.map((e)=>{
            const subj = this.subjectForKey(e.key);
            if (e.created.getTime() >= min) {
                return this.jsm.streams.purge(this.stream, {
                    filter: subj,
                    keep: 1
                });
            } else {
                return this.jsm.streams.purge(this.stream, {
                    filter: subj,
                    keep: 0
                });
            }
        });
        const purged = await Promise.all(proms);
        purged.unshift({
            success: true,
            purged: 0
        });
        return purged.reduce((pv, cv)=>{
            pv.purged += cv.purged;
            return pv;
        });
    }
    async _deleteOrPurge(k, op, opts) {
        if (!this.hasWildcards(k)) {
            return this._doDeleteOrPurge(k, op, opts);
        }
        const iter = await this.keys(k);
        const buf = [];
        for await (const k of iter){
            buf.push(this._doDeleteOrPurge(k, op));
            if (buf.length === 100) {
                await Promise.all(buf);
                buf.length = 0;
            }
        }
        if (buf.length > 0) {
            await Promise.all(buf);
        }
    }
    async _doDeleteOrPurge(k, op, opts) {
        const ek = this.encodeKey(k);
        this.validateKey(ek);
        const h = headers();
        h.set(kvOperationHdr, op);
        if (op === "PURGE") {
            h.set(JsHeaders.RollupHdr, JsHeaders.RollupValueSubject);
        }
        if (opts?.previousSeq) {
            h.set(PubHeaders.ExpectedLastSubjectSequenceHdr, `${opts.previousSeq}`);
        }
        await this.js.publish(this.subjectForKey(ek, true), Empty, {
            headers: h
        });
    }
    _buildCC(k, content, opts = {}) {
        const a = !Array.isArray(k) ? [
            k
        ] : k;
        let filter_subjects = a.map((k)=>{
            const ek = this.encodeKey(k);
            this.validateSearchKey(k);
            return this.fullKeyName(ek);
        });
        let deliver_policy = DeliverPolicy.LastPerSubject;
        if (content === KvWatchInclude.AllHistory) {
            deliver_policy = DeliverPolicy.All;
        }
        if (content === KvWatchInclude.UpdatesOnly) {
            deliver_policy = DeliverPolicy.New;
        }
        let filter_subject = undefined;
        if (filter_subjects.length === 1) {
            filter_subject = filter_subjects[0];
            filter_subjects = undefined;
        }
        return Object.assign({
            deliver_policy,
            "ack_policy": AckPolicy.None,
            filter_subjects,
            filter_subject,
            "flow_control": true,
            "idle_heartbeat": nanos(5 * 1000)
        }, opts);
    }
    remove(k) {
        return this.purge(k);
    }
    async history(opts = {}) {
        const k = opts.key ?? ">";
        const qi = new QueuedIteratorImpl();
        const co = {};
        co.headers_only = opts.headers_only || false;
        let fn;
        fn = ()=>{
            qi.stop();
        };
        let count = 0;
        const cc = this._buildCC(k, KvWatchInclude.AllHistory, co);
        const subj = cc.filter_subject;
        const copts = consumerOpts(cc);
        copts.bindStream(this.stream);
        copts.orderedConsumer();
        copts.callback((err, jm)=>{
            if (err) {
                qi.stop(err);
                return;
            }
            if (jm) {
                const e = this.jmToEntry(jm);
                qi.push(e);
                qi.received++;
                if (fn && count > 0 && qi.received >= count || jm.info.pending === 0) {
                    qi.push(fn);
                    fn = undefined;
                }
            }
        });
        const sub = await this.js.subscribe(subj, copts);
        if (fn) {
            const { info: { last } } = sub;
            const expect = last.num_pending + last.delivered.consumer_seq;
            if (expect === 0 || qi.received >= expect) {
                try {
                    fn();
                } catch (err) {
                    qi.stop(err);
                } finally{
                    fn = undefined;
                }
            } else {
                count = expect;
            }
        }
        qi._data = sub;
        qi.iterClosed.then(()=>{
            sub.unsubscribe();
        });
        sub.closed.then(()=>{
            qi.stop();
        }).catch((err)=>{
            qi.stop(err);
        });
        return qi;
    }
    canSetWatcherName() {
        const jsi = this.js;
        const nci = jsi.nc;
        const { ok } = nci.features.get(Feature.JS_NEW_CONSUMER_CREATE_API);
        return ok;
    }
    async watch(opts = {}) {
        const k = opts.key ?? ">";
        const qi = new QueuedIteratorImpl();
        const co = {};
        co.headers_only = opts.headers_only || false;
        let content = KvWatchInclude.LastValue;
        if (opts.include === KvWatchInclude.AllHistory) {
            content = KvWatchInclude.AllHistory;
        } else if (opts.include === KvWatchInclude.UpdatesOnly) {
            content = KvWatchInclude.UpdatesOnly;
        }
        const ignoreDeletes = opts.ignoreDeletes === true;
        let fn = opts.initializedFn;
        let count = 0;
        const cc = this._buildCC(k, content, co);
        const subj = cc.filter_subject;
        const copts = consumerOpts(cc);
        if (this.canSetWatcherName()) {
            copts.consumerName(nuid.next());
        }
        copts.bindStream(this.stream);
        if (opts.resumeFromRevision && opts.resumeFromRevision > 0) {
            copts.startSequence(opts.resumeFromRevision);
        }
        copts.orderedConsumer();
        copts.callback((err, jm)=>{
            if (err) {
                qi.stop(err);
                return;
            }
            if (jm) {
                const e = this.jmToEntry(jm);
                if (ignoreDeletes && e.operation === "DEL") {
                    return;
                }
                qi.push(e);
                qi.received++;
                if (fn && (count > 0 && qi.received >= count || jm.info.pending === 0)) {
                    qi.push(fn);
                    fn = undefined;
                }
            }
        });
        const sub = await this.js.subscribe(subj, copts);
        if (fn) {
            const { info: { last } } = sub;
            const expect = last.num_pending + last.delivered.consumer_seq;
            if (expect === 0 || qi.received >= expect) {
                try {
                    fn();
                } catch (err) {
                    qi.stop(err);
                } finally{
                    fn = undefined;
                }
            } else {
                count = expect;
            }
        }
        qi._data = sub;
        qi.iterClosed.then(()=>{
            sub.unsubscribe();
        });
        sub.closed.then(()=>{
            qi.stop();
        }).catch((err)=>{
            qi.stop(err);
        });
        return qi;
    }
    async keys(k = ">") {
        const keys = new QueuedIteratorImpl();
        const cc = this._buildCC(k, KvWatchInclude.LastValue, {
            headers_only: true
        });
        const subj = Array.isArray(k) ? ">" : cc.filter_subject;
        const copts = consumerOpts(cc);
        copts.bindStream(this.stream);
        copts.orderedConsumer();
        const sub = await this.js.subscribe(subj, copts);
        (async ()=>{
            for await (const jm of sub){
                const op = jm.headers?.get(kvOperationHdr);
                if (op !== "DEL" && op !== "PURGE") {
                    const key = this.decodeKey(jm.subject.substring(this.prefixLen));
                    keys.push(key);
                }
                if (jm.info.pending === 0) {
                    sub.unsubscribe();
                }
            }
        })().then(()=>{
            keys.stop();
        }).catch((err)=>{
            keys.stop(err);
        });
        const si = sub;
        if (si.info.last.num_pending === 0) {
            sub.unsubscribe();
        }
        return keys;
    }
    purgeBucket(opts) {
        return this.jsm.streams.purge(this.bucketName(), opts);
    }
    destroy() {
        return this.jsm.streams.delete(this.bucketName());
    }
    async status() {
        const nc = this.js.nc;
        const cluster = nc.info?.cluster ?? "";
        const bn = this.bucketName();
        const si = await this.jsm.streams.info(bn);
        return new KvStatusImpl(si, cluster);
    }
}
class KvStatusImpl {
    si;
    cluster;
    constructor(si, cluster = ""){
        this.si = si;
        this.cluster = cluster;
    }
    get bucket() {
        return this.si.config.name.startsWith(kvPrefix) ? this.si.config.name.substring(kvPrefix.length) : this.si.config.name;
    }
    get values() {
        return this.si.state.messages;
    }
    get history() {
        return this.si.config.max_msgs_per_subject;
    }
    get ttl() {
        return millis(this.si.config.max_age);
    }
    get bucket_location() {
        return this.cluster;
    }
    get backingStore() {
        return this.si.config.storage;
    }
    get storage() {
        return this.si.config.storage;
    }
    get replicas() {
        return this.si.config.num_replicas;
    }
    get description() {
        return this.si.config.description ?? "";
    }
    get maxBucketSize() {
        return this.si.config.max_bytes;
    }
    get maxValueSize() {
        return this.si.config.max_msg_size;
    }
    get max_bytes() {
        return this.si.config.max_bytes;
    }
    get placement() {
        return this.si.config.placement || {
            cluster: "",
            tags: []
        };
    }
    get placementCluster() {
        return this.si.config.placement?.cluster ?? "";
    }
    get republish() {
        return this.si.config.republish ?? {
            src: "",
            dest: ""
        };
    }
    get streamInfo() {
        return this.si;
    }
    get size() {
        return this.si.state.bytes;
    }
    get metadata() {
        return this.si.config.metadata ?? {};
    }
    get compression() {
        if (this.si.config.compression) {
            return this.si.config.compression !== StoreCompression.None;
        }
        return false;
    }
}
const osPrefix = "OBJ_";
const digestType = "SHA-256=";
function objectStoreStreamName(bucket) {
    validateBucket(bucket);
    return `${osPrefix}${bucket}`;
}
function objectStoreBucketName(stream) {
    if (stream.startsWith(osPrefix)) {
        return stream.substring(4);
    }
    return stream;
}
class ObjectStoreStatusImpl {
    si;
    backingStore;
    constructor(si){
        this.si = si;
        this.backingStore = "JetStream";
    }
    get bucket() {
        return objectStoreBucketName(this.si.config.name);
    }
    get description() {
        return this.si.config.description ?? "";
    }
    get ttl() {
        return this.si.config.max_age;
    }
    get storage() {
        return this.si.config.storage;
    }
    get replicas() {
        return this.si.config.num_replicas;
    }
    get sealed() {
        return this.si.config.sealed;
    }
    get size() {
        return this.si.state.bytes;
    }
    get streamInfo() {
        return this.si;
    }
    get metadata() {
        return this.si.config.metadata;
    }
    get compression() {
        if (this.si.config.compression) {
            return this.si.config.compression !== StoreCompression.None;
        }
        return false;
    }
}
function convertStreamSourceDomain(s) {
    if (s === undefined) {
        return undefined;
    }
    const { domain } = s;
    if (domain === undefined) {
        return s;
    }
    const copy = Object.assign({}, s);
    delete copy.domain;
    if (domain === "") {
        return copy;
    }
    if (copy.external) {
        throw new Error("domain and external are both set");
    }
    copy.external = {
        api: `$JS.${domain}.API`
    };
    return copy;
}
var PullConsumerType;
(function(PullConsumerType) {
    PullConsumerType[PullConsumerType["Unset"] = -1] = "Unset";
    PullConsumerType[PullConsumerType["Consume"] = 0] = "Consume";
    PullConsumerType[PullConsumerType["Fetch"] = 1] = "Fetch";
})(PullConsumerType || (PullConsumerType = {}));
var ConsumerEvents;
(function(ConsumerEvents) {
    ConsumerEvents["HeartbeatsMissed"] = "heartbeats_missed";
    ConsumerEvents["ConsumerNotFound"] = "consumer_not_found";
    ConsumerEvents["StreamNotFound"] = "stream_not_found";
    ConsumerEvents["ConsumerDeleted"] = "consumer_deleted";
    ConsumerEvents["OrderedConsumerRecreated"] = "ordered_consumer_recreated";
    ConsumerEvents["NoResponders"] = "no_responders";
})(ConsumerEvents || (ConsumerEvents = {}));
var ConsumerDebugEvents;
(function(ConsumerDebugEvents) {
    ConsumerDebugEvents["DebugEvent"] = "debug";
    ConsumerDebugEvents["Discard"] = "discard";
    ConsumerDebugEvents["Reset"] = "reset";
    ConsumerDebugEvents["Next"] = "next";
})(ConsumerDebugEvents || (ConsumerDebugEvents = {}));
const ACK = Uint8Array.of(43, 65, 67, 75);
const NAK = Uint8Array.of(45, 78, 65, 75);
const WPI = Uint8Array.of(43, 87, 80, 73);
const NXT = Uint8Array.of(43, 78, 88, 84);
const TERM = Uint8Array.of(43, 84, 69, 82, 77);
const SPACE = Uint8Array.of(32);
function toJsMsg(m, ackTimeout = 5000) {
    return new JsMsgImpl(m, ackTimeout);
}
class PullConsumerMessagesImpl extends QueuedIteratorImpl {
    consumer;
    opts;
    sub;
    monitor;
    pending;
    inbox;
    refilling;
    pong;
    callback;
    timeout;
    cleanupHandler;
    listeners;
    statusIterator;
    forOrderedConsumer;
    resetHandler;
    abortOnMissingResource;
    bind;
    inBackOff;
    constructor(c, opts, refilling = false){
        super();
        this.consumer = c;
        const copts = opts;
        this.opts = this.parseOptions(opts, refilling);
        this.callback = copts.callback || null;
        this.noIterator = typeof this.callback === "function";
        this.monitor = null;
        this.pong = null;
        this.pending = {
            msgs: 0,
            bytes: 0,
            requests: 0
        };
        this.refilling = refilling;
        this.timeout = null;
        this.inbox = createInbox(c.api.nc.options.inboxPrefix);
        this.listeners = [];
        this.forOrderedConsumer = false;
        this.abortOnMissingResource = copts.abort_on_missing_resource === true;
        this.bind = copts.bind === true;
        this.inBackOff = false;
        this.start();
    }
    start() {
        const { max_messages, max_bytes, idle_heartbeat, threshold_bytes, threshold_messages } = this.opts;
        this.closed().then((err)=>{
            if (this.cleanupHandler) {
                try {
                    this.cleanupHandler(err);
                } catch (_err) {}
            }
        });
        const { sub } = this;
        if (sub) {
            sub.unsubscribe();
        }
        this.sub = this.consumer.api.nc.subscribe(this.inbox, {
            callback: (err, msg)=>{
                if (err) {
                    this.stop(err);
                    return;
                }
                this.monitor?.work();
                const isProtocol = msg.subject === this.inbox;
                if (isProtocol) {
                    if (isHeartbeatMsg(msg)) {
                        return;
                    }
                    const code = msg.headers?.code;
                    const description = msg.headers?.description?.toLowerCase() || "unknown";
                    const { msgsLeft, bytesLeft } = this.parseDiscard(msg.headers);
                    if (msgsLeft > 0 || bytesLeft > 0) {
                        this.pending.msgs -= msgsLeft;
                        this.pending.bytes -= bytesLeft;
                        this.pending.requests--;
                        this.notify(ConsumerDebugEvents.Discard, {
                            msgsLeft,
                            bytesLeft
                        });
                    } else {
                        if (code === 400) {
                            this.stop(new NatsError(description, `${code}`));
                            return;
                        } else if (code === 409 && description === "consumer deleted") {
                            this.notify(ConsumerEvents.ConsumerDeleted, `${code} ${description}`);
                            if (!this.refilling || this.abortOnMissingResource) {
                                const error = new NatsError(description, `${code}`);
                                this.stop(error);
                                return;
                            }
                        } else if (code === 503) {
                            this.notify(ConsumerEvents.NoResponders, `${code} No Responders`);
                            if (!this.refilling || this.abortOnMissingResource) {
                                const error = new NatsError("no responders", `${code}`);
                                this.stop(error);
                                return;
                            }
                        } else {
                            this.notify(ConsumerDebugEvents.DebugEvent, `${code} ${description}`);
                        }
                    }
                } else {
                    this._push(toJsMsg(msg, this.consumer.api.timeout));
                    this.received++;
                    if (this.pending.msgs) {
                        this.pending.msgs--;
                    }
                    if (this.pending.bytes) {
                        this.pending.bytes -= msg.size();
                    }
                }
                if (this.pending.msgs === 0 && this.pending.bytes === 0) {
                    this.pending.requests = 0;
                }
                if (this.refilling) {
                    if (max_messages && this.pending.msgs <= threshold_messages || max_bytes && this.pending.bytes <= threshold_bytes) {
                        const batch = this.pullOptions();
                        this.pull(batch);
                    }
                } else if (this.pending.requests === 0) {
                    this._push(()=>{
                        this.stop();
                    });
                }
            }
        });
        this.sub.closed.then(()=>{
            if (this.sub.draining) {
                this._push(()=>{
                    this.stop();
                });
            }
        });
        if (idle_heartbeat) {
            this.monitor = new IdleHeartbeatMonitor(idle_heartbeat, (data)=>{
                this.notify(ConsumerEvents.HeartbeatsMissed, data);
                this.resetPending().then(()=>{}).catch(()=>{});
                return false;
            }, {
                maxOut: 2
            });
        }
        (async ()=>{
            const status = this.consumer.api.nc.status();
            this.statusIterator = status;
            for await (const s of status){
                switch(s.type){
                    case Events.Disconnect:
                        this.monitor?.cancel();
                        break;
                    case Events.Reconnect:
                        this.resetPending().then((ok)=>{
                            if (ok) {
                                this.monitor?.restart();
                            }
                        }).catch(()=>{});
                        break;
                    default:
                }
            }
        })();
        this.pull(this.pullOptions());
    }
    _push(r) {
        if (!this.callback) {
            super.push(r);
        } else {
            const fn = typeof r === "function" ? r : null;
            try {
                if (!fn) {
                    this.callback(r);
                } else {
                    fn();
                }
            } catch (err) {
                this.stop(err);
            }
        }
    }
    notify(type, data) {
        if (this.listeners.length > 0) {
            (()=>{
                this.listeners.forEach((l)=>{
                    if (!l.done) {
                        l.push({
                            type,
                            data
                        });
                    }
                });
            })();
        }
    }
    resetPending() {
        return this.bind ? this.resetPendingNoInfo() : this.resetPendingWithInfo();
    }
    resetPendingNoInfo() {
        this.pending.msgs = 0;
        this.pending.bytes = 0;
        this.pending.requests = 0;
        this.pull(this.pullOptions());
        return Promise.resolve(true);
    }
    async resetPendingWithInfo() {
        if (this.inBackOff) {
            return false;
        }
        let notFound = 0;
        let streamNotFound = 0;
        const bo = backoff([
            this.opts.expires
        ]);
        let attempt = 0;
        while(true){
            if (this.done) {
                return false;
            }
            if (this.consumer.api.nc.isClosed()) {
                console.error("aborting resetPending - connection is closed");
                return false;
            }
            try {
                await this.consumer.info();
                this.inBackOff = false;
                notFound = 0;
                this.pending.msgs = 0;
                this.pending.bytes = 0;
                this.pending.requests = 0;
                this.pull(this.pullOptions());
                return true;
            } catch (err) {
                if (err.message === "stream not found") {
                    streamNotFound++;
                    this.notify(ConsumerEvents.StreamNotFound, streamNotFound);
                    if (!this.refilling || this.abortOnMissingResource) {
                        this.stop(err);
                        return false;
                    }
                } else if (err.message === "consumer not found") {
                    notFound++;
                    this.notify(ConsumerEvents.ConsumerNotFound, notFound);
                    if (this.resetHandler) {
                        try {
                            this.resetHandler();
                        } catch (_) {}
                    }
                    if (!this.refilling || this.abortOnMissingResource) {
                        this.stop(err);
                        return false;
                    }
                    if (this.forOrderedConsumer) {
                        return false;
                    }
                } else {
                    notFound = 0;
                    streamNotFound = 0;
                }
                this.inBackOff = true;
                const to = bo.backoff(attempt);
                const de = delay(to);
                await Promise.race([
                    de,
                    this.consumer.api.nc.closed()
                ]);
                de.cancel();
                attempt++;
            }
        }
    }
    pull(opts) {
        this.pending.bytes += opts.max_bytes ?? 0;
        this.pending.msgs += opts.batch ?? 0;
        this.pending.requests++;
        const nc = this.consumer.api.nc;
        this._push(()=>{
            nc.publish(`${this.consumer.api.prefix}.CONSUMER.MSG.NEXT.${this.consumer.stream}.${this.consumer.name}`, this.consumer.api.jc.encode(opts), {
                reply: this.inbox
            });
            this.notify(ConsumerDebugEvents.Next, opts);
        });
    }
    pullOptions() {
        const batch = this.opts.max_messages - this.pending.msgs;
        const max_bytes = this.opts.max_bytes - this.pending.bytes;
        const idle_heartbeat = nanos(this.opts.idle_heartbeat);
        const expires = nanos(this.opts.expires);
        return {
            batch,
            max_bytes,
            idle_heartbeat,
            expires
        };
    }
    parseDiscard(headers) {
        const discard = {
            msgsLeft: 0,
            bytesLeft: 0
        };
        const msgsLeft = headers?.get(JsHeaders.PendingMessagesHdr);
        if (msgsLeft) {
            discard.msgsLeft = parseInt(msgsLeft);
        }
        const bytesLeft = headers?.get(JsHeaders.PendingBytesHdr);
        if (bytesLeft) {
            discard.bytesLeft = parseInt(bytesLeft);
        }
        return discard;
    }
    trackTimeout(t) {
        this.timeout = t;
    }
    close() {
        this.stop();
        return this.iterClosed;
    }
    closed() {
        return this.iterClosed;
    }
    clearTimers() {
        this.monitor?.cancel();
        this.monitor = null;
        this.timeout?.cancel();
        this.timeout = null;
    }
    setCleanupHandler(fn) {
        this.cleanupHandler = fn;
    }
    stop(err) {
        if (this.done) {
            return;
        }
        this.sub?.unsubscribe();
        this.clearTimers();
        this.statusIterator?.stop();
        this._push(()=>{
            super.stop(err);
            this.listeners.forEach((n)=>{
                n.stop();
            });
        });
    }
    parseOptions(opts, refilling = false) {
        const args = opts || {};
        args.max_messages = args.max_messages || 0;
        args.max_bytes = args.max_bytes || 0;
        if (args.max_messages !== 0 && args.max_bytes !== 0) {
            throw new Error(`only specify one of max_messages or max_bytes`);
        }
        if (args.max_messages === 0) {
            args.max_messages = 100;
        }
        args.expires = args.expires || 30_000;
        if (args.expires < 1000) {
            throw new Error("expires should be at least 1000ms");
        }
        args.idle_heartbeat = args.idle_heartbeat || args.expires / 2;
        args.idle_heartbeat = args.idle_heartbeat > 30_000 ? 30_000 : args.idle_heartbeat;
        if (refilling) {
            const minMsgs = Math.round(args.max_messages * .75) || 1;
            args.threshold_messages = args.threshold_messages || minMsgs;
            const minBytes = Math.round(args.max_bytes * .75) || 1;
            args.threshold_bytes = args.threshold_bytes || minBytes;
        }
        return args;
    }
    status() {
        const iter = new QueuedIteratorImpl();
        this.listeners.push(iter);
        return Promise.resolve(iter);
    }
}
class OrderedConsumerMessages extends QueuedIteratorImpl {
    src;
    listeners;
    constructor(){
        super();
        this.listeners = [];
    }
    setSource(src) {
        if (this.src) {
            this.src.resetHandler = undefined;
            this.src.setCleanupHandler();
            this.src.stop();
        }
        this.src = src;
        this.src.setCleanupHandler((err)=>{
            this.stop(err || undefined);
        });
        (async ()=>{
            const status = await this.src.status();
            for await (const s of status){
                this.notify(s.type, s.data);
            }
        })().catch(()=>{});
    }
    notify(type, data) {
        if (this.listeners.length > 0) {
            (()=>{
                this.listeners.forEach((l)=>{
                    if (!l.done) {
                        l.push({
                            type,
                            data
                        });
                    }
                });
            })();
        }
    }
    stop(err) {
        if (this.done) {
            return;
        }
        this.src?.stop(err);
        super.stop(err);
        this.listeners.forEach((n)=>{
            n.stop();
        });
    }
    close() {
        this.stop();
        return this.iterClosed;
    }
    closed() {
        return this.iterClosed;
    }
    status() {
        const iter = new QueuedIteratorImpl();
        this.listeners.push(iter);
        return Promise.resolve(iter);
    }
}
class PullConsumerImpl {
    api;
    _info;
    stream;
    name;
    constructor(api, info){
        this.api = api;
        this._info = info;
        this.stream = info.stream_name;
        this.name = info.name;
    }
    consume(opts = {
        max_messages: 100,
        expires: 30_000
    }) {
        return Promise.resolve(new PullConsumerMessagesImpl(this, opts, true));
    }
    fetch(opts = {
        max_messages: 100,
        expires: 30_000
    }) {
        const m = new PullConsumerMessagesImpl(this, opts, false);
        const to = Math.round(m.opts.expires * 1.05);
        const timer = timeout(to);
        m.closed().catch(()=>{}).finally(()=>{
            timer.cancel();
        });
        timer.catch(()=>{
            m.close().catch();
        });
        m.trackTimeout(timer);
        return Promise.resolve(m);
    }
    next(opts = {
        expires: 30_000
    }) {
        const d = deferred();
        const fopts = opts;
        fopts.max_messages = 1;
        const iter = new PullConsumerMessagesImpl(this, fopts, false);
        const to = Math.round(iter.opts.expires * 1.05);
        if (to >= 60_000) {
            (async ()=>{
                for await (const s of (await iter.status())){
                    if (s.type === ConsumerEvents.HeartbeatsMissed && s.data >= 2) {
                        d.reject(new Error("consumer missed heartbeats"));
                        break;
                    }
                }
            })().catch();
        }
        (async ()=>{
            for await (const m of iter){
                d.resolve(m);
                break;
            }
        })().catch(()=>{});
        const timer = timeout(to);
        iter.closed().then((err)=>{
            err ? d.reject(err) : d.resolve(null);
        }).catch((err)=>{
            d.reject(err);
        }).finally(()=>{
            timer.cancel();
        });
        timer.catch((_err)=>{
            d.resolve(null);
            iter.close().catch();
        });
        iter.trackTimeout(timer);
        return d;
    }
    delete() {
        const { stream_name, name } = this._info;
        return this.api.delete(stream_name, name);
    }
    info(cached = false) {
        if (cached) {
            return Promise.resolve(this._info);
        }
        const { stream_name, name } = this._info;
        return this.api.info(stream_name, name).then((ci)=>{
            this._info = ci;
            return this._info;
        });
    }
}
class OrderedPullConsumerImpl {
    api;
    consumerOpts;
    consumer;
    opts;
    cursor;
    stream;
    namePrefix;
    serial;
    currentConsumer;
    userCallback;
    iter;
    type;
    startSeq;
    maxInitialReset;
    constructor(api, stream, opts = {}){
        this.api = api;
        this.stream = stream;
        this.cursor = {
            stream_seq: 1,
            deliver_seq: 0
        };
        this.namePrefix = nuid.next();
        if (typeof opts.name_prefix === "string") {
            minValidation("name_prefix", opts.name_prefix);
            this.namePrefix = opts.name_prefix + this.namePrefix;
        }
        this.serial = 0;
        this.currentConsumer = null;
        this.userCallback = null;
        this.iter = null;
        this.type = PullConsumerType.Unset;
        this.consumerOpts = opts;
        this.maxInitialReset = 30;
        this.startSeq = this.consumerOpts.opt_start_seq || 0;
        this.cursor.stream_seq = this.startSeq > 0 ? this.startSeq - 1 : 0;
    }
    getConsumerOpts(seq) {
        this.serial++;
        const name = `${this.namePrefix}_${this.serial}`;
        seq = seq === 0 ? 1 : seq;
        const config = {
            name,
            deliver_policy: DeliverPolicy.StartSequence,
            opt_start_seq: seq,
            ack_policy: AckPolicy.None,
            inactive_threshold: nanos(5 * 60 * 1000),
            num_replicas: 1
        };
        if (this.consumerOpts.headers_only === true) {
            config.headers_only = true;
        }
        if (Array.isArray(this.consumerOpts.filterSubjects)) {
            config.filter_subjects = this.consumerOpts.filterSubjects;
        }
        if (typeof this.consumerOpts.filterSubjects === "string") {
            config.filter_subject = this.consumerOpts.filterSubjects;
        }
        if (this.consumerOpts.replay_policy) {
            config.replay_policy = this.consumerOpts.replay_policy;
        }
        if (seq === this.startSeq + 1) {
            config.deliver_policy = this.consumerOpts.deliver_policy || DeliverPolicy.StartSequence;
            if (this.consumerOpts.deliver_policy === DeliverPolicy.LastPerSubject || this.consumerOpts.deliver_policy === DeliverPolicy.New || this.consumerOpts.deliver_policy === DeliverPolicy.Last) {
                delete config.opt_start_seq;
                config.deliver_policy = this.consumerOpts.deliver_policy;
            }
            if (config.deliver_policy === DeliverPolicy.LastPerSubject) {
                if (typeof config.filter_subjects === "undefined" && typeof config.filter_subject === "undefined") {
                    config.filter_subject = ">";
                }
            }
            if (this.consumerOpts.opt_start_time) {
                delete config.opt_start_seq;
                config.deliver_policy = DeliverPolicy.StartTime;
                config.opt_start_time = this.consumerOpts.opt_start_time;
            }
            if (this.consumerOpts.inactive_threshold) {
                config.inactive_threshold = nanos(this.consumerOpts.inactive_threshold);
            }
        }
        return config;
    }
    async resetConsumer(seq = 0) {
        nuid.next();
        const isNew = this.serial === 0;
        this.consumer?.delete().catch(()=>{});
        seq = seq === 0 ? 1 : seq;
        this.cursor.deliver_seq = 0;
        const config = this.getConsumerOpts(seq);
        config.max_deliver = 1;
        config.mem_storage = true;
        const bo = backoff([
            this.opts?.expires || 30_000
        ]);
        let ci;
        for(let i = 0;; i++){
            try {
                ci = await this.api.add(this.stream, config);
                this.iter?.notify(ConsumerEvents.OrderedConsumerRecreated, ci.name);
                break;
            } catch (err) {
                if (err.message === "stream not found") {
                    this.iter?.notify(ConsumerEvents.StreamNotFound, i);
                    if (this.type === PullConsumerType.Fetch || this.opts.abort_on_missing_resource === true) {
                        this.iter?.stop(err);
                        return Promise.reject(err);
                    }
                }
                if (isNew && i >= this.maxInitialReset) {
                    throw err;
                } else {
                    await delay(bo.backoff(i + 1));
                }
            }
        }
        return ci;
    }
    internalHandler(serial) {
        return (m)=>{
            if (this.serial !== serial) {
                return;
            }
            const dseq = m.info.deliverySequence;
            if (dseq !== this.cursor.deliver_seq + 1) {
                this.notifyOrderedResetAndReset();
                return;
            }
            this.cursor.deliver_seq = dseq;
            this.cursor.stream_seq = m.info.streamSequence;
            if (this.userCallback) {
                this.userCallback(m);
            } else {
                this.iter?.push(m);
            }
        };
    }
    async reset(opts = {
        max_messages: 100,
        expires: 30_000
    }, info) {
        info = info || {};
        const fromFetch = info.fromFetch || false;
        const orderedReset = info.orderedReset || false;
        if (this.type === PullConsumerType.Fetch && orderedReset) {
            this.iter?.src.stop();
            await this.iter?.closed();
            this.currentConsumer = null;
            return;
        }
        if (this.currentConsumer === null || orderedReset) {
            this.currentConsumer = await this.resetConsumer(this.cursor.stream_seq + 1);
        }
        if (this.iter === null || fromFetch) {
            this.iter = new OrderedConsumerMessages();
        }
        this.consumer = new PullConsumerImpl(this.api, this.currentConsumer);
        const copts = opts;
        copts.callback = this.internalHandler(this.serial);
        let msgs = null;
        if (this.type === PullConsumerType.Fetch && fromFetch) {
            msgs = await this.consumer.fetch(opts);
        } else if (this.type === PullConsumerType.Consume) {
            msgs = await this.consumer.consume(opts);
        }
        const msgsImpl = msgs;
        msgsImpl.forOrderedConsumer = true;
        msgsImpl.resetHandler = ()=>{
            this.notifyOrderedResetAndReset();
        };
        this.iter.setSource(msgsImpl);
    }
    notifyOrderedResetAndReset() {
        this.iter?.notify(ConsumerDebugEvents.Reset, "");
        this.reset(this.opts, {
            orderedReset: true
        });
    }
    async consume(opts = {
        max_messages: 100,
        expires: 30_000
    }) {
        const copts = opts;
        if (copts.bind) {
            return Promise.reject(new Error("bind is not supported"));
        }
        if (this.type === PullConsumerType.Fetch) {
            return Promise.reject(new Error("ordered consumer initialized as fetch"));
        }
        if (this.type === PullConsumerType.Consume) {
            return Promise.reject(new Error("ordered consumer doesn't support concurrent consume"));
        }
        const { callback } = opts;
        if (callback) {
            this.userCallback = callback;
        }
        this.type = PullConsumerType.Consume;
        this.opts = opts;
        await this.reset(opts);
        return this.iter;
    }
    async fetch(opts = {
        max_messages: 100,
        expires: 30_000
    }) {
        const copts = opts;
        if (copts.bind) {
            return Promise.reject(new Error("bind is not supported"));
        }
        if (this.type === PullConsumerType.Consume) {
            return Promise.reject(new Error("ordered consumer already initialized as consume"));
        }
        if (this.iter?.done === false) {
            return Promise.reject(new Error("ordered consumer doesn't support concurrent fetch"));
        }
        const { callback } = opts;
        if (callback) {
            this.userCallback = callback;
        }
        this.type = PullConsumerType.Fetch;
        this.opts = opts;
        await this.reset(opts, {
            fromFetch: true
        });
        return this.iter;
    }
    async next(opts = {
        expires: 30_000
    }) {
        const copts = opts;
        if (copts.bind) {
            return Promise.reject(new Error("bind is not supported"));
        }
        copts.max_messages = 1;
        const d = deferred();
        copts.callback = (m)=>{
            this.userCallback = null;
            d.resolve(m);
        };
        const iter = await this.fetch(copts);
        iter.iterClosed.then((err)=>{
            if (err) {
                d.reject(err);
            }
            d.resolve(null);
        }).catch((err)=>{
            d.reject(err);
        });
        return d;
    }
    delete() {
        if (!this.currentConsumer) {
            return Promise.resolve(false);
        }
        return this.api.delete(this.stream, this.currentConsumer.name).then((tf)=>{
            return Promise.resolve(tf);
        }).catch((err)=>{
            return Promise.reject(err);
        }).finally(()=>{
            this.currentConsumer = null;
        });
    }
    async info(cached) {
        if (this.currentConsumer == null) {
            this.currentConsumer = await this.resetConsumer(this.startSeq);
            return Promise.resolve(this.currentConsumer);
        }
        if (cached && this.currentConsumer) {
            return Promise.resolve(this.currentConsumer);
        }
        return this.api.info(this.stream, this.currentConsumer.name);
    }
}
class ConsumersImpl {
    api;
    notified;
    constructor(api){
        this.api = api;
        this.notified = false;
    }
    checkVersion() {
        const fv = this.api.nc.features.get(Feature.JS_SIMPLIFICATION);
        if (!fv.ok) {
            return Promise.reject(new Error(`consumers framework is only supported on servers ${fv.min} or better`));
        }
        return Promise.resolve();
    }
    getPullConsumerFor(ci) {
        if (ci.config.deliver_subject !== undefined) {
            throw new Error("push consumer not supported");
        }
        return new PullConsumerImpl(this.api, ci);
    }
    async get(stream, name = {}) {
        if (typeof name === "object") {
            return this.ordered(stream, name);
        }
        await this.checkVersion();
        return this.api.info(stream, name).then((ci)=>{
            if (ci.config.deliver_subject !== undefined) {
                return Promise.reject(new Error("push consumer not supported"));
            }
            return new PullConsumerImpl(this.api, ci);
        }).catch((err)=>{
            return Promise.reject(err);
        });
    }
    async ordered(stream, opts) {
        await this.checkVersion();
        const impl = this.api;
        const sapi = new StreamAPIImpl(impl.nc, impl.opts);
        return sapi.info(stream).then((_si)=>{
            return Promise.resolve(new OrderedPullConsumerImpl(this.api, stream, opts));
        }).catch((err)=>{
            return Promise.reject(err);
        });
    }
}
class StreamImpl {
    api;
    _info;
    constructor(api, info){
        this.api = api;
        this._info = info;
    }
    get name() {
        return this._info.config.name;
    }
    alternates() {
        return this.info().then((si)=>{
            return si.alternates ? si.alternates : [];
        });
    }
    async best() {
        await this.info();
        if (this._info.alternates) {
            const asi = await this.api.info(this._info.alternates[0].name);
            return new StreamImpl(this.api, asi);
        } else {
            return this;
        }
    }
    info(cached = false, opts) {
        if (cached) {
            return Promise.resolve(this._info);
        }
        return this.api.info(this.name, opts).then((si)=>{
            this._info = si;
            return this._info;
        });
    }
    getConsumerFromInfo(ci) {
        return new ConsumersImpl(new ConsumerAPIImpl(this.api.nc, this.api.opts)).getPullConsumerFor(ci);
    }
    getConsumer(name) {
        return new ConsumersImpl(new ConsumerAPIImpl(this.api.nc, this.api.opts)).get(this.name, name);
    }
    getMessage(query) {
        return this.api.getMessage(this.name, query);
    }
    deleteMessage(seq, erase) {
        return this.api.deleteMessage(this.name, seq, erase);
    }
}
class StreamAPIImpl extends BaseApiClient {
    constructor(nc, opts){
        super(nc, opts);
    }
    checkStreamConfigVersions(cfg) {
        const nci = this.nc;
        if (cfg.metadata) {
            const { min, ok } = nci.features.get(Feature.JS_STREAM_CONSUMER_METADATA);
            if (!ok) {
                throw new Error(`stream 'metadata' requires server ${min}`);
            }
        }
        if (cfg.first_seq) {
            const { min, ok } = nci.features.get(Feature.JS_STREAM_FIRST_SEQ);
            if (!ok) {
                throw new Error(`stream 'first_seq' requires server ${min}`);
            }
        }
        if (cfg.subject_transform) {
            const { min, ok } = nci.features.get(Feature.JS_STREAM_SUBJECT_TRANSFORM);
            if (!ok) {
                throw new Error(`stream 'subject_transform' requires server ${min}`);
            }
        }
        if (cfg.compression) {
            const { min, ok } = nci.features.get(Feature.JS_STREAM_COMPRESSION);
            if (!ok) {
                throw new Error(`stream 'compression' requires server ${min}`);
            }
        }
        if (cfg.consumer_limits) {
            const { min, ok } = nci.features.get(Feature.JS_DEFAULT_CONSUMER_LIMITS);
            if (!ok) {
                throw new Error(`stream 'consumer_limits' requires server ${min}`);
            }
        }
        function validateStreamSource(context, src) {
            const count = src?.subject_transforms?.length || 0;
            if (count > 0) {
                const { min, ok } = nci.features.get(Feature.JS_STREAM_SOURCE_SUBJECT_TRANSFORM);
                if (!ok) {
                    throw new Error(`${context} 'subject_transforms' requires server ${min}`);
                }
            }
        }
        if (cfg.sources) {
            cfg.sources.forEach((src)=>{
                validateStreamSource("stream sources", src);
            });
        }
        if (cfg.mirror) {
            validateStreamSource("stream mirror", cfg.mirror);
        }
    }
    async add(cfg = {}) {
        this.checkStreamConfigVersions(cfg);
        validateStreamName(cfg.name);
        cfg.mirror = convertStreamSourceDomain(cfg.mirror);
        cfg.sources = cfg.sources?.map(convertStreamSourceDomain);
        const r = await this._request(`${this.prefix}.STREAM.CREATE.${cfg.name}`, cfg);
        const si = r;
        this._fixInfo(si);
        return si;
    }
    async delete(stream) {
        validateStreamName(stream);
        const r = await this._request(`${this.prefix}.STREAM.DELETE.${stream}`);
        const cr = r;
        return cr.success;
    }
    async update(name, cfg = {}) {
        if (typeof name === "object") {
            const sc = name;
            name = sc.name;
            cfg = sc;
            console.trace(`\u001B[33m >> streams.update(config: StreamConfig) api changed to streams.update(name: string, config: StreamUpdateConfig) - this shim will be removed - update your code.  \u001B[0m`);
        }
        this.checkStreamConfigVersions(cfg);
        validateStreamName(name);
        const old = await this.info(name);
        const update = Object.assign(old.config, cfg);
        update.mirror = convertStreamSourceDomain(update.mirror);
        update.sources = update.sources?.map(convertStreamSourceDomain);
        const r = await this._request(`${this.prefix}.STREAM.UPDATE.${name}`, update);
        const si = r;
        this._fixInfo(si);
        return si;
    }
    async info(name, data) {
        validateStreamName(name);
        const subj = `${this.prefix}.STREAM.INFO.${name}`;
        const r = await this._request(subj, data);
        let si = r;
        let { total, limit } = si;
        let have = si.state.subjects ? Object.getOwnPropertyNames(si.state.subjects).length : 1;
        if (total && total > have) {
            const infos = [
                si
            ];
            const paged = data || {};
            let i = 0;
            while(total > have){
                i++;
                paged.offset = limit * i;
                const r = await this._request(subj, paged);
                total = r.total;
                infos.push(r);
                const count = Object.getOwnPropertyNames(r.state.subjects).length;
                have += count;
                if (count < limit) {
                    break;
                }
            }
            let subjects = {};
            for(let i = 0; i < infos.length; i++){
                si = infos[i];
                if (si.state.subjects) {
                    subjects = Object.assign(subjects, si.state.subjects);
                }
            }
            si.offset = 0;
            si.total = 0;
            si.limit = 0;
            si.state.subjects = subjects;
        }
        this._fixInfo(si);
        return si;
    }
    list(subject = "") {
        const payload = subject?.length ? {
            subject
        } : {};
        const listerFilter = (v)=>{
            const slr = v;
            slr.streams.forEach((si)=>{
                this._fixInfo(si);
            });
            return slr.streams;
        };
        const subj = `${this.prefix}.STREAM.LIST`;
        return new ListerImpl(subj, listerFilter, this, payload);
    }
    _fixInfo(si) {
        si.config.sealed = si.config.sealed || false;
        si.config.deny_delete = si.config.deny_delete || false;
        si.config.deny_purge = si.config.deny_purge || false;
        si.config.allow_rollup_hdrs = si.config.allow_rollup_hdrs || false;
    }
    async purge(name, opts) {
        if (opts) {
            const { keep, seq } = opts;
            if (typeof keep === "number" && typeof seq === "number") {
                throw new Error("can specify one of keep or seq");
            }
        }
        validateStreamName(name);
        const v = await this._request(`${this.prefix}.STREAM.PURGE.${name}`, opts);
        return v;
    }
    async deleteMessage(stream, seq, erase = true) {
        validateStreamName(stream);
        const dr = {
            seq
        };
        if (!erase) {
            dr.no_erase = true;
        }
        const r = await this._request(`${this.prefix}.STREAM.MSG.DELETE.${stream}`, dr);
        const cr = r;
        return cr.success;
    }
    async getMessage(stream, query) {
        validateStreamName(stream);
        const r = await this._request(`${this.prefix}.STREAM.MSG.GET.${stream}`, query);
        const sm = r;
        return new StoredMsgImpl(sm);
    }
    find(subject) {
        return this.findStream(subject);
    }
    listKvs() {
        const filter = (v)=>{
            const slr = v;
            const kvStreams = slr.streams.filter((v)=>{
                return v.config.name.startsWith(kvPrefix);
            });
            kvStreams.forEach((si)=>{
                this._fixInfo(si);
            });
            let cluster = "";
            if (kvStreams.length) {
                cluster = this.nc.info?.cluster ?? "";
            }
            const status = kvStreams.map((si)=>{
                return new KvStatusImpl(si, cluster);
            });
            return status;
        };
        const subj = `${this.prefix}.STREAM.LIST`;
        return new ListerImpl(subj, filter, this);
    }
    listObjectStores() {
        const filter = (v)=>{
            const slr = v;
            const objStreams = slr.streams.filter((v)=>{
                return v.config.name.startsWith(osPrefix);
            });
            objStreams.forEach((si)=>{
                this._fixInfo(si);
            });
            const status = objStreams.map((si)=>{
                return new ObjectStoreStatusImpl(si);
            });
            return status;
        };
        const subj = `${this.prefix}.STREAM.LIST`;
        return new ListerImpl(subj, filter, this);
    }
    names(subject = "") {
        const payload = subject?.length ? {
            subject
        } : {};
        const listerFilter = (v)=>{
            const sr = v;
            return sr.streams;
        };
        const subj = `${this.prefix}.STREAM.NAMES`;
        return new ListerImpl(subj, listerFilter, this, payload);
    }
    async get(name) {
        const si = await this.info(name);
        return Promise.resolve(new StreamImpl(this, si));
    }
}
class DirectStreamAPIImpl extends BaseApiClient {
    constructor(nc, opts){
        super(nc, opts);
    }
    async getMessage(stream, query) {
        validateStreamName(stream);
        let qq = query;
        const { last_by_subj } = qq;
        if (last_by_subj) {
            qq = null;
        }
        const payload = qq ? this.jc.encode(qq) : Empty;
        const pre = this.opts.apiPrefix || "$JS.API";
        const subj = last_by_subj ? `${pre}.DIRECT.GET.${stream}.${last_by_subj}` : `${pre}.DIRECT.GET.${stream}`;
        const r = await this.nc.request(subj, payload, {
            timeout: this.timeout
        });
        const err = checkJsError(r);
        if (err) {
            return Promise.reject(err);
        }
        const dm = new DirectMsgImpl(r);
        return Promise.resolve(dm);
    }
    async getBatch(stream, opts) {
        validateStreamName(stream);
        const pre = this.opts.apiPrefix || "$JS.API";
        const subj = `${pre}.DIRECT.GET.${stream}`;
        if (!Array.isArray(opts.multi_last) || opts.multi_last.length === 0) {
            return Promise.reject("multi_last is required");
        }
        const payload = JSON.stringify(opts, (key, value)=>{
            if (key === "up_to_time" && value instanceof Date) {
                return value.toISOString();
            }
            return value;
        });
        const iter = new QueuedIteratorImpl();
        const raw = await this.nc.requestMany(subj, payload, {
            strategy: RequestStrategy.SentinelMsg
        });
        (async ()=>{
            let gotFirst = false;
            let badServer = false;
            let badRequest;
            for await (const m of raw){
                if (!gotFirst) {
                    gotFirst = true;
                    const code = m.headers?.code || 0;
                    if (code !== 0 && code < 200 || code > 299) {
                        badRequest = m.headers?.description.toLowerCase();
                        break;
                    }
                    const v = m.headers?.get("Nats-Num-Pending");
                    if (v === "") {
                        badServer = true;
                        break;
                    }
                }
                if (m.data.length === 0) {
                    break;
                }
                iter.push(new DirectMsgImpl(m));
            }
            iter.push(()=>{
                if (badServer) {
                    throw new Error("batch direct get not supported by the server");
                }
                if (badRequest) {
                    throw new Error(`bad request: ${badRequest}`);
                }
                iter.stop();
            });
        })();
        return Promise.resolve(iter);
    }
}
class DirectMsgImpl {
    data;
    header;
    static jc;
    constructor(m){
        if (!m.headers) {
            throw new Error("headers expected");
        }
        this.data = m.data;
        this.header = m.headers;
    }
    get subject() {
        return this.header.last(DirectMsgHeaders.Subject);
    }
    get seq() {
        const v = this.header.last(DirectMsgHeaders.Sequence);
        return typeof v === "string" ? parseInt(v) : 0;
    }
    get time() {
        return new Date(Date.parse(this.timestamp));
    }
    get timestamp() {
        return this.header.last(DirectMsgHeaders.TimeStamp);
    }
    get stream() {
        return this.header.last(DirectMsgHeaders.Stream);
    }
    json(reviver) {
        return JSONCodec(reviver).decode(this.data);
    }
    string() {
        return TD.decode(this.data);
    }
}
class JetStreamManagerImpl extends BaseApiClient {
    streams;
    consumers;
    direct;
    constructor(nc, opts){
        super(nc, opts);
        this.streams = new StreamAPIImpl(nc, opts);
        this.consumers = new ConsumerAPIImpl(nc, opts);
        this.direct = new DirectStreamAPIImpl(nc, opts);
    }
    async getAccountInfo() {
        const r = await this._request(`${this.prefix}.INFO`);
        return r;
    }
    jetstream() {
        return this.nc.jetstream(this.getOptions());
    }
    advisories() {
        const iter = new QueuedIteratorImpl();
        this.nc.subscribe(`$JS.EVENT.ADVISORY.>`, {
            callback: (err, msg)=>{
                if (err) {
                    throw err;
                }
                try {
                    const d = this.parseJsResponse(msg);
                    const chunks = d.type.split(".");
                    const kind = chunks[chunks.length - 1];
                    iter.push({
                        kind: kind,
                        data: d
                    });
                } catch (err) {
                    iter.stop(err);
                }
            }
        });
        return iter;
    }
}
class StoredMsgImpl {
    _header;
    smr;
    static jc;
    constructor(smr){
        this.smr = smr;
    }
    get subject() {
        return this.smr.message.subject;
    }
    get seq() {
        return this.smr.message.seq;
    }
    get timestamp() {
        return this.smr.message.time;
    }
    get time() {
        return new Date(Date.parse(this.timestamp));
    }
    get data() {
        return this.smr.message.data ? this._parse(this.smr.message.data) : Empty;
    }
    get header() {
        if (!this._header) {
            if (this.smr.message.hdrs) {
                const hd = this._parse(this.smr.message.hdrs);
                this._header = MsgHdrsImpl.decode(hd);
            } else {
                this._header = headers();
            }
        }
        return this._header;
    }
    _parse(s) {
        const bs = atob(s);
        const len = bs.length;
        const bytes = new Uint8Array(len);
        for(let i = 0; i < len; i++){
            bytes[i] = bs.charCodeAt(i);
        }
        return bytes;
    }
    json(reviver) {
        return JSONCodec(reviver).decode(this.data);
    }
    string() {
        return TD.decode(this.data);
    }
}
class StreamsImpl {
    api;
    constructor(api){
        this.api = api;
    }
    get(stream) {
        return this.api.info(stream).then((si)=>{
            return new StreamImpl(this.api, si);
        });
    }
}
class ObjectInfoImpl {
    info;
    hdrs;
    constructor(oi){
        this.info = oi;
    }
    get name() {
        return this.info.name;
    }
    get description() {
        return this.info.description ?? "";
    }
    get headers() {
        if (!this.hdrs) {
            this.hdrs = MsgHdrsImpl.fromRecord(this.info.headers || {});
        }
        return this.hdrs;
    }
    get options() {
        return this.info.options;
    }
    get bucket() {
        return this.info.bucket;
    }
    get chunks() {
        return this.info.chunks;
    }
    get deleted() {
        return this.info.deleted ?? false;
    }
    get digest() {
        return this.info.digest;
    }
    get mtime() {
        return this.info.mtime;
    }
    get nuid() {
        return this.info.nuid;
    }
    get size() {
        return this.info.size;
    }
    get revision() {
        return this.info.revision;
    }
    get metadata() {
        return this.info.metadata || {};
    }
    isLink() {
        return this.info.options?.link !== undefined && this.info.options?.link !== null;
    }
}
function toServerObjectStoreMeta(meta) {
    const v = {
        name: meta.name,
        description: meta.description ?? "",
        options: meta.options,
        metadata: meta.metadata
    };
    if (meta.headers) {
        const mhi = meta.headers;
        v.headers = mhi.toRecord();
    }
    return v;
}
function emptyReadableStream() {
    return new ReadableStream({
        pull (c) {
            c.enqueue(new Uint8Array(0));
            c.close();
        }
    });
}
class ObjectStoreImpl {
    jsm;
    js;
    stream;
    name;
    constructor(name, jsm, js){
        this.name = name;
        this.jsm = jsm;
        this.js = js;
    }
    _checkNotEmpty(name) {
        if (!name || name.length === 0) {
            return {
                name,
                error: new Error("name cannot be empty")
            };
        }
        return {
            name
        };
    }
    async info(name) {
        const info = await this.rawInfo(name);
        return info ? new ObjectInfoImpl(info) : null;
    }
    async list() {
        const buf = [];
        const iter = await this.watch({
            ignoreDeletes: true,
            includeHistory: true
        });
        for await (const info of iter){
            if (info === null) {
                break;
            }
            buf.push(info);
        }
        return Promise.resolve(buf);
    }
    async rawInfo(name) {
        const { name: obj, error } = this._checkNotEmpty(name);
        if (error) {
            return Promise.reject(error);
        }
        const meta = this._metaSubject(obj);
        try {
            const m = await this.jsm.streams.getMessage(this.stream, {
                last_by_subj: meta
            });
            const jc = JSONCodec();
            const soi = jc.decode(m.data);
            soi.revision = m.seq;
            return soi;
        } catch (err) {
            if (err.code === "404") {
                return null;
            }
            return Promise.reject(err);
        }
    }
    async _si(opts) {
        try {
            return await this.jsm.streams.info(this.stream, opts);
        } catch (err) {
            const nerr = err;
            if (nerr.code === "404") {
                return null;
            }
            return Promise.reject(err);
        }
    }
    async seal() {
        let info = await this._si();
        if (info === null) {
            return Promise.reject(new Error("object store not found"));
        }
        info.config.sealed = true;
        info = await this.jsm.streams.update(this.stream, info.config);
        return Promise.resolve(new ObjectStoreStatusImpl(info));
    }
    async status(opts) {
        const info = await this._si(opts);
        if (info === null) {
            return Promise.reject(new Error("object store not found"));
        }
        return Promise.resolve(new ObjectStoreStatusImpl(info));
    }
    destroy() {
        return this.jsm.streams.delete(this.stream);
    }
    async _put(meta, rs, opts) {
        const jsopts = this.js.getOptions();
        opts = opts || {
            timeout: jsopts.timeout
        };
        opts.timeout = opts.timeout || jsopts.timeout;
        opts.previousRevision = opts.previousRevision ?? undefined;
        const { timeout, previousRevision } = opts;
        const si = this.js.nc.info;
        const maxPayload = si?.max_payload || 1024;
        meta = meta || {};
        meta.options = meta.options || {};
        let maxChunk = meta.options?.max_chunk_size || 128 * 1024;
        maxChunk = maxChunk > maxPayload ? maxPayload : maxChunk;
        meta.options.max_chunk_size = maxChunk;
        const old = await this.info(meta.name);
        const { name: n, error } = this._checkNotEmpty(meta.name);
        if (error) {
            return Promise.reject(error);
        }
        const id = nuid.next();
        const chunkSubj = this._chunkSubject(id);
        const metaSubj = this._metaSubject(n);
        const info = Object.assign({
            bucket: this.name,
            nuid: id,
            size: 0,
            chunks: 0
        }, toServerObjectStoreMeta(meta));
        const d = deferred();
        const proms = [];
        const db = new DataBuffer();
        try {
            const reader = rs ? rs.getReader() : null;
            const sha = J.create();
            while(true){
                const { done, value } = reader ? await reader.read() : {
                    done: true,
                    value: undefined
                };
                if (done) {
                    if (db.size() > 0) {
                        const payload = db.drain();
                        sha.update(payload);
                        info.chunks++;
                        info.size += payload.length;
                        proms.push(this.js.publish(chunkSubj, payload, {
                            timeout
                        }));
                    }
                    await Promise.all(proms);
                    proms.length = 0;
                    info.mtime = new Date().toISOString();
                    const digest = Base64UrlPaddedCodec.encode(sha.digest());
                    info.digest = `${digestType}${digest}`;
                    info.deleted = false;
                    const h = headers();
                    if (typeof previousRevision === "number") {
                        h.set(PubHeaders.ExpectedLastSubjectSequenceHdr, `${previousRevision}`);
                    }
                    h.set(JsHeaders.RollupHdr, JsHeaders.RollupValueSubject);
                    const pa = await this.js.publish(metaSubj, JSONCodec().encode(info), {
                        headers: h,
                        timeout
                    });
                    info.revision = pa.seq;
                    if (old) {
                        try {
                            await this.jsm.streams.purge(this.stream, {
                                filter: `$O.${this.name}.C.${old.nuid}`
                            });
                        } catch (_err) {}
                    }
                    d.resolve(new ObjectInfoImpl(info));
                    break;
                }
                if (value) {
                    db.fill(value);
                    while(db.size() > maxChunk){
                        info.chunks++;
                        info.size += maxChunk;
                        const payload = db.drain(meta.options.max_chunk_size);
                        sha.update(payload);
                        proms.push(this.js.publish(chunkSubj, payload, {
                            timeout
                        }));
                    }
                }
            }
        } catch (err) {
            await this.jsm.streams.purge(this.stream, {
                filter: chunkSubj
            });
            d.reject(err);
        }
        return d;
    }
    putBlob(meta, data, opts) {
        function readableStreamFrom(data) {
            return new ReadableStream({
                pull (controller) {
                    controller.enqueue(data);
                    controller.close();
                }
            });
        }
        if (data === null) {
            data = new Uint8Array(0);
        }
        return this.put(meta, readableStreamFrom(data), opts);
    }
    put(meta, rs, opts) {
        if (meta?.options?.link) {
            return Promise.reject(new Error("link cannot be set when putting the object in bucket"));
        }
        return this._put(meta, rs, opts);
    }
    async getBlob(name) {
        async function fromReadableStream(rs) {
            const buf = new DataBuffer();
            const reader = rs.getReader();
            while(true){
                const { done, value } = await reader.read();
                if (done) {
                    return buf.drain();
                }
                if (value && value.length) {
                    buf.fill(value);
                }
            }
        }
        const r = await this.get(name);
        if (r === null) {
            return Promise.resolve(null);
        }
        const vs = await Promise.all([
            r.error,
            fromReadableStream(r.data)
        ]);
        if (vs[0]) {
            return Promise.reject(vs[0]);
        } else {
            return Promise.resolve(vs[1]);
        }
    }
    async get(name) {
        const info = await this.rawInfo(name);
        if (info === null) {
            return Promise.resolve(null);
        }
        if (info.deleted) {
            return Promise.resolve(null);
        }
        if (info.options && info.options.link) {
            const ln = info.options.link.name || "";
            if (ln === "") {
                throw new Error("link is a bucket");
            }
            const os = info.options.link.bucket !== this.name ? await ObjectStoreImpl.create(this.js, info.options.link.bucket) : this;
            return os.get(ln);
        }
        if (!info.digest.startsWith(digestType)) {
            return Promise.reject(new Error(`unknown digest type: ${info.digest}`));
        }
        const digest = parseSha256(info.digest.substring(8));
        if (digest === null) {
            return Promise.reject(new Error(`unable to parse digest: ${info.digest}`));
        }
        const d = deferred();
        const r = {
            info: new ObjectInfoImpl(info),
            error: d
        };
        if (info.size === 0) {
            r.data = emptyReadableStream();
            d.resolve(null);
            return Promise.resolve(r);
        }
        let controller;
        const oc = consumerOpts();
        oc.orderedConsumer();
        const sha = J.create();
        const subj = `$O.${this.name}.C.${info.nuid}`;
        const sub = await this.js.subscribe(subj, oc);
        (async ()=>{
            for await (const jm of sub){
                if (jm.data.length > 0) {
                    sha.update(jm.data);
                    controller.enqueue(jm.data);
                }
                if (jm.info.pending === 0) {
                    if (!checkSha256(digest, sha.digest())) {
                        controller.error(new Error(`received a corrupt object, digests do not match received: ${info.digest} calculated ${digest}`));
                    } else {
                        controller.close();
                    }
                    sub.unsubscribe();
                }
            }
        })().then(()=>{
            d.resolve();
        }).catch((err)=>{
            controller.error(err);
            d.reject(err);
        });
        r.data = new ReadableStream({
            start (c) {
                controller = c;
            },
            cancel () {
                sub.unsubscribe();
            }
        });
        return r;
    }
    linkStore(name, bucket) {
        if (!(bucket instanceof ObjectStoreImpl)) {
            return Promise.reject("bucket required");
        }
        const osi = bucket;
        const { name: n, error } = this._checkNotEmpty(name);
        if (error) {
            return Promise.reject(error);
        }
        const meta = {
            name: n,
            options: {
                link: {
                    bucket: osi.name
                }
            }
        };
        return this._put(meta, null);
    }
    async link(name, info) {
        const { name: n, error } = this._checkNotEmpty(name);
        if (error) {
            return Promise.reject(error);
        }
        if (info.deleted) {
            return Promise.reject(new Error("src object is deleted"));
        }
        if (info.isLink()) {
            return Promise.reject(new Error("src object is a link"));
        }
        const dest = await this.rawInfo(name);
        if (dest !== null && !dest.deleted) {
            return Promise.reject(new Error("an object already exists with that name"));
        }
        const link = {
            bucket: info.bucket,
            name: info.name
        };
        const mm = {
            name: n,
            bucket: info.bucket,
            options: {
                link: link
            }
        };
        await this.js.publish(this._metaSubject(name), JSON.stringify(mm));
        const i = await this.info(name);
        return Promise.resolve(i);
    }
    async delete(name) {
        const info = await this.rawInfo(name);
        if (info === null) {
            return Promise.resolve({
                purged: 0,
                success: false
            });
        }
        info.deleted = true;
        info.size = 0;
        info.chunks = 0;
        info.digest = "";
        const jc = JSONCodec();
        const h = headers();
        h.set(JsHeaders.RollupHdr, JsHeaders.RollupValueSubject);
        await this.js.publish(this._metaSubject(info.name), jc.encode(info), {
            headers: h
        });
        return this.jsm.streams.purge(this.stream, {
            filter: this._chunkSubject(info.nuid)
        });
    }
    async update(name, meta = {}) {
        const info = await this.rawInfo(name);
        if (info === null) {
            return Promise.reject(new Error("object not found"));
        }
        if (info.deleted) {
            return Promise.reject(new Error("cannot update meta for a deleted object"));
        }
        meta.name = meta.name ?? info.name;
        const { name: n, error } = this._checkNotEmpty(meta.name);
        if (error) {
            return Promise.reject(error);
        }
        if (name !== meta.name) {
            const i = await this.info(meta.name);
            if (i && !i.deleted) {
                return Promise.reject(new Error("an object already exists with that name"));
            }
        }
        meta.name = n;
        const ii = Object.assign({}, info, toServerObjectStoreMeta(meta));
        const ack = await this.js.publish(this._metaSubject(ii.name), JSON.stringify(ii));
        if (name !== meta.name) {
            await this.jsm.streams.purge(this.stream, {
                filter: this._metaSubject(name)
            });
        }
        return Promise.resolve(ack);
    }
    async watch(opts = {}) {
        opts.includeHistory = opts.includeHistory ?? false;
        opts.ignoreDeletes = opts.ignoreDeletes ?? false;
        let initialized = false;
        const qi = new QueuedIteratorImpl();
        const subj = this._metaSubjectAll();
        try {
            await this.jsm.streams.getMessage(this.stream, {
                last_by_subj: subj
            });
        } catch (err) {
            if (err.code === "404") {
                qi.push(null);
                initialized = true;
            } else {
                qi.stop(err);
            }
        }
        const jc = JSONCodec();
        const copts = consumerOpts();
        copts.orderedConsumer();
        if (opts.includeHistory) {
            copts.deliverLastPerSubject();
        } else {
            initialized = true;
            copts.deliverNew();
        }
        copts.callback((err, jm)=>{
            if (err) {
                qi.stop(err);
                return;
            }
            if (jm !== null) {
                const oi = jc.decode(jm.data);
                if (oi.deleted && opts.ignoreDeletes === true) {} else {
                    qi.push(oi);
                }
                if (jm.info?.pending === 0 && !initialized) {
                    initialized = true;
                    qi.push(null);
                }
            }
        });
        const sub = await this.js.subscribe(subj, copts);
        qi._data = sub;
        qi.iterClosed.then(()=>{
            sub.unsubscribe();
        });
        sub.closed.then(()=>{
            qi.stop();
        }).catch((err)=>{
            qi.stop(err);
        });
        return qi;
    }
    _chunkSubject(id) {
        return `$O.${this.name}.C.${id}`;
    }
    _metaSubject(n) {
        return `$O.${this.name}.M.${Base64UrlPaddedCodec.encode(n)}`;
    }
    _metaSubjectAll() {
        return `$O.${this.name}.M.>`;
    }
    async init(opts = {}) {
        try {
            this.stream = objectStoreStreamName(this.name);
        } catch (err) {
            return Promise.reject(err);
        }
        const max_age = opts?.ttl || 0;
        delete opts.ttl;
        const sc = Object.assign({
            max_age
        }, opts);
        sc.name = this.stream;
        sc.num_replicas = opts.replicas ?? 1;
        sc.allow_direct = true;
        sc.allow_rollup_hdrs = true;
        sc.discard = DiscardPolicy.New;
        sc.subjects = [
            `$O.${this.name}.C.>`,
            `$O.${this.name}.M.>`
        ];
        if (opts.placement) {
            sc.placement = opts.placement;
        }
        if (opts.metadata) {
            sc.metadata = opts.metadata;
        }
        if (typeof opts.compression === "boolean") {
            sc.compression = opts.compression ? StoreCompression.S2 : StoreCompression.None;
        }
        try {
            await this.jsm.streams.info(sc.name);
        } catch (err) {
            if (err.message === "stream not found") {
                await this.jsm.streams.add(sc);
            }
        }
    }
    static async create(js, name, opts = {}) {
        const jsm = await js.jetstreamManager();
        const os = new ObjectStoreImpl(name, jsm, js);
        await os.init(opts);
        return Promise.resolve(os);
    }
}
class ViewsImpl {
    js;
    constructor(js){
        this.js = js;
    }
    kv(name, opts = {}) {
        const jsi = this.js;
        const { ok, min } = jsi.nc.features.get(Feature.JS_KV);
        if (!ok) {
            return Promise.reject(new Error(`kv is only supported on servers ${min} or better`));
        }
        if (opts.bindOnly) {
            return Bucket.bind(this.js, name, opts);
        }
        return Bucket.create(this.js, name, opts);
    }
    os(name, opts = {}) {
        if (typeof crypto?.subtle?.digest !== "function") {
            return Promise.reject(new Error("objectstore: unable to calculate hashes - crypto.subtle.digest with sha256 support is required"));
        }
        const jsi = this.js;
        const { ok, min } = jsi.nc.features.get(Feature.JS_OBJECTSTORE);
        if (!ok) {
            return Promise.reject(new Error(`objectstore is only supported on servers ${min} or better`));
        }
        return ObjectStoreImpl.create(this.js, name, opts);
    }
}
class JetStreamClientImpl extends BaseApiClient {
    consumers;
    streams;
    consumerAPI;
    streamAPI;
    constructor(nc, opts){
        super(nc, opts);
        this.consumerAPI = new ConsumerAPIImpl(nc, opts);
        this.streamAPI = new StreamAPIImpl(nc, opts);
        this.consumers = new ConsumersImpl(this.consumerAPI);
        this.streams = new StreamsImpl(this.streamAPI);
    }
    jetstreamManager(checkAPI) {
        if (checkAPI === undefined) {
            checkAPI = this.opts.checkAPI;
        }
        const opts = Object.assign({}, this.opts, {
            checkAPI
        });
        return this.nc.jetstreamManager(opts);
    }
    get apiPrefix() {
        return this.prefix;
    }
    get views() {
        return new ViewsImpl(this);
    }
    async publish(subj, data = Empty, opts) {
        opts = opts || {};
        opts.expect = opts.expect || {};
        const mh = opts?.headers || headers();
        if (opts) {
            if (opts.msgID) {
                mh.set(PubHeaders.MsgIdHdr, opts.msgID);
            }
            if (opts.expect.lastMsgID) {
                mh.set(PubHeaders.ExpectedLastMsgIdHdr, opts.expect.lastMsgID);
            }
            if (opts.expect.streamName) {
                mh.set(PubHeaders.ExpectedStreamHdr, opts.expect.streamName);
            }
            if (typeof opts.expect.lastSequence === "number") {
                mh.set(PubHeaders.ExpectedLastSeqHdr, `${opts.expect.lastSequence}`);
            }
            if (typeof opts.expect.lastSubjectSequence === "number") {
                mh.set(PubHeaders.ExpectedLastSubjectSequenceHdr, `${opts.expect.lastSubjectSequence}`);
            }
        }
        const to = opts.timeout || this.timeout;
        const ro = {};
        if (to) {
            ro.timeout = to;
        }
        if (opts) {
            ro.headers = mh;
        }
        let { retries, retry_delay } = opts;
        retries = retries || 1;
        retry_delay = retry_delay || 250;
        let r;
        for(let i = 0; i < retries; i++){
            try {
                r = await this.nc.request(subj, data, ro);
                break;
            } catch (err) {
                const ne = err;
                if (ne.code === "503" && i + 1 < retries) {
                    await delay(retry_delay);
                } else {
                    throw err;
                }
            }
        }
        const pa = this.parseJsResponse(r);
        if (pa.stream === "") {
            throw NatsError.errorForCode(ErrorCode.JetStreamInvalidAck);
        }
        pa.duplicate = pa.duplicate ? pa.duplicate : false;
        return pa;
    }
    async pull(stream, durable, expires = 0) {
        validateStreamName(stream);
        validateDurableName(durable);
        let timeout = this.timeout;
        if (expires > timeout) {
            timeout = expires;
        }
        expires = expires < 0 ? 0 : nanos(expires);
        const pullOpts = {
            batch: 1,
            no_wait: expires === 0,
            expires
        };
        const msg = await this.nc.request(`${this.prefix}.CONSUMER.MSG.NEXT.${stream}.${durable}`, this.jc.encode(pullOpts), {
            noMux: true,
            timeout
        });
        const err = checkJsError(msg);
        if (err) {
            throw err;
        }
        return toJsMsg(msg, this.timeout);
    }
    fetch(stream, durable, opts = {}) {
        validateStreamName(stream);
        validateDurableName(durable);
        let timer = null;
        const trackBytes = (opts.max_bytes ?? 0) > 0;
        let receivedBytes = 0;
        const max_bytes = trackBytes ? opts.max_bytes : 0;
        let monitor = null;
        const args = {};
        args.batch = opts.batch || 1;
        if (max_bytes) {
            const fv = this.nc.features.get(Feature.JS_PULL_MAX_BYTES);
            if (!fv.ok) {
                throw new Error(`max_bytes is only supported on servers ${fv.min} or better`);
            }
            args.max_bytes = max_bytes;
        }
        args.no_wait = opts.no_wait || false;
        if (args.no_wait && args.expires) {
            args.expires = 0;
        }
        const expires = opts.expires || 0;
        if (expires) {
            args.expires = nanos(expires);
        }
        if (expires === 0 && args.no_wait === false) {
            throw new Error("expires or no_wait is required");
        }
        const hb = opts.idle_heartbeat || 0;
        if (hb) {
            args.idle_heartbeat = nanos(hb);
            if (opts.delay_heartbeat === true) {
                args.idle_heartbeat = nanos(hb * 4);
            }
        }
        const qi = new QueuedIteratorImpl();
        const wants = args.batch;
        let received = 0;
        qi.protocolFilterFn = (jm, _ingest = false)=>{
            const jsmi = jm;
            if (isHeartbeatMsg(jsmi.msg)) {
                monitor?.work();
                return false;
            }
            return true;
        };
        qi.dispatchedFn = (m)=>{
            if (m) {
                if (trackBytes) {
                    receivedBytes += m.data.length;
                }
                received++;
                if (timer && m.info.pending === 0) {
                    return;
                }
                if (qi.getPending() === 1 && m.info.pending === 0 || wants === received || max_bytes > 0 && receivedBytes >= max_bytes) {
                    qi.stop();
                }
            }
        };
        const inbox = createInbox(this.nc.options.inboxPrefix);
        const sub = this.nc.subscribe(inbox, {
            max: opts.batch,
            callback: (err, msg)=>{
                if (err === null) {
                    err = checkJsError(msg);
                }
                if (err !== null) {
                    if (timer) {
                        timer.cancel();
                        timer = null;
                    }
                    if (isNatsError(err)) {
                        qi.stop(hideNonTerminalJsErrors(err) === null ? undefined : err);
                    } else {
                        qi.stop(err);
                    }
                } else {
                    monitor?.work();
                    qi.received++;
                    qi.push(toJsMsg(msg, this.timeout));
                }
            }
        });
        if (expires) {
            timer = timeout(expires);
            timer.catch(()=>{
                if (!sub.isClosed()) {
                    sub.drain().catch(()=>{});
                    timer = null;
                }
                if (monitor) {
                    monitor.cancel();
                }
            });
        }
        (async ()=>{
            try {
                if (hb) {
                    monitor = new IdleHeartbeatMonitor(hb, (v)=>{
                        qi.push(()=>{
                            qi.err = new NatsError(`${Js409Errors.IdleHeartbeatMissed}: ${v}`, ErrorCode.JetStreamIdleHeartBeat);
                        });
                        return true;
                    });
                }
            } catch (_err) {}
            await sub.closed;
            if (timer !== null) {
                timer.cancel();
                timer = null;
            }
            if (monitor) {
                monitor.cancel();
            }
            qi.stop();
        })().catch();
        this.nc.publish(`${this.prefix}.CONSUMER.MSG.NEXT.${stream}.${durable}`, this.jc.encode(args), {
            reply: inbox
        });
        return qi;
    }
    async pullSubscribe(subject, opts = consumerOpts()) {
        const cso = await this._processOptions(subject, opts);
        if (cso.ordered) {
            throw new Error("pull subscribers cannot be be ordered");
        }
        if (cso.config.deliver_subject) {
            throw new Error("consumer info specifies deliver_subject - pull consumers cannot have deliver_subject set");
        }
        const ackPolicy = cso.config.ack_policy;
        if (ackPolicy === AckPolicy.None || ackPolicy === AckPolicy.All) {
            throw new Error("ack policy for pull consumers must be explicit");
        }
        const so = this._buildTypedSubscriptionOpts(cso);
        const sub = new JetStreamPullSubscriptionImpl(this, cso.deliver, so);
        sub.info = cso;
        try {
            await this._maybeCreateConsumer(cso);
        } catch (err) {
            sub.unsubscribe();
            throw err;
        }
        return sub;
    }
    async subscribe(subject, opts = consumerOpts()) {
        const cso = await this._processOptions(subject, opts);
        if (!cso.isBind && !cso.config.deliver_subject) {
            throw new Error("push consumer requires deliver_subject");
        }
        const so = this._buildTypedSubscriptionOpts(cso);
        const sub = new JetStreamSubscriptionImpl(this, cso.deliver, so);
        sub.info = cso;
        try {
            await this._maybeCreateConsumer(cso);
        } catch (err) {
            sub.unsubscribe();
            throw err;
        }
        sub._maybeSetupHbMonitoring();
        return sub;
    }
    async _processOptions(subject, opts = consumerOpts()) {
        const jsi = isConsumerOptsBuilder(opts) ? opts.getOpts() : opts;
        jsi.isBind = isConsumerOptsBuilder(opts) ? opts.isBind : false;
        jsi.flow_control = {
            heartbeat_count: 0,
            fc_count: 0,
            consumer_restarts: 0
        };
        if (jsi.ordered) {
            jsi.ordered_consumer_sequence = {
                stream_seq: 0,
                delivery_seq: 0
            };
            if (jsi.config.ack_policy !== AckPolicy.NotSet && jsi.config.ack_policy !== AckPolicy.None) {
                throw new NatsError("ordered consumer: ack_policy can only be set to 'none'", ErrorCode.ApiError);
            }
            if (jsi.config.durable_name && jsi.config.durable_name.length > 0) {
                throw new NatsError("ordered consumer: durable_name cannot be set", ErrorCode.ApiError);
            }
            if (jsi.config.deliver_subject && jsi.config.deliver_subject.length > 0) {
                throw new NatsError("ordered consumer: deliver_subject cannot be set", ErrorCode.ApiError);
            }
            if (jsi.config.max_deliver !== undefined && jsi.config.max_deliver > 1) {
                throw new NatsError("ordered consumer: max_deliver cannot be set", ErrorCode.ApiError);
            }
            if (jsi.config.deliver_group && jsi.config.deliver_group.length > 0) {
                throw new NatsError("ordered consumer: deliver_group cannot be set", ErrorCode.ApiError);
            }
            jsi.config.deliver_subject = createInbox(this.nc.options.inboxPrefix);
            jsi.config.ack_policy = AckPolicy.None;
            jsi.config.max_deliver = 1;
            jsi.config.flow_control = true;
            jsi.config.idle_heartbeat = jsi.config.idle_heartbeat || nanos(5000);
            jsi.config.ack_wait = nanos(22 * 60 * 60 * 1000);
            jsi.config.mem_storage = true;
            jsi.config.num_replicas = 1;
        }
        if (jsi.config.ack_policy === AckPolicy.NotSet) {
            jsi.config.ack_policy = AckPolicy.All;
        }
        jsi.api = this;
        jsi.config = jsi.config || {};
        jsi.stream = jsi.stream ? jsi.stream : await this.findStream(subject);
        jsi.attached = false;
        if (jsi.config.durable_name) {
            try {
                const info = await this.consumerAPI.info(jsi.stream, jsi.config.durable_name);
                if (info) {
                    if (info.config.filter_subject && info.config.filter_subject !== subject) {
                        throw new Error("subject does not match consumer");
                    }
                    const qn = jsi.config.deliver_group ?? "";
                    if (qn === "" && info.push_bound === true) {
                        throw new Error(`duplicate subscription`);
                    }
                    const rqn = info.config.deliver_group ?? "";
                    if (qn !== rqn) {
                        if (rqn === "") {
                            throw new Error(`durable requires no queue group`);
                        } else {
                            throw new Error(`durable requires queue group '${rqn}'`);
                        }
                    }
                    jsi.last = info;
                    jsi.config = info.config;
                    jsi.attached = true;
                    if (!jsi.config.durable_name) {
                        jsi.name = info.name;
                    }
                }
            } catch (err) {
                if (err.code !== "404") {
                    throw err;
                }
            }
        }
        if (!jsi.attached && jsi.config.filter_subject === undefined && jsi.config.filter_subjects === undefined) {
            jsi.config.filter_subject = subject;
        }
        jsi.deliver = jsi.config.deliver_subject || createInbox(this.nc.options.inboxPrefix);
        return jsi;
    }
    _buildTypedSubscriptionOpts(jsi) {
        const so = {};
        so.adapter = msgAdapter(jsi.callbackFn === undefined, this.timeout);
        so.ingestionFilterFn = JetStreamClientImpl.ingestionFn(jsi.ordered);
        so.protocolFilterFn = (jm, ingest = false)=>{
            const jsmi = jm;
            if (isFlowControlMsg(jsmi.msg)) {
                if (!ingest) {
                    jsmi.msg.respond();
                }
                return false;
            }
            return true;
        };
        if (!jsi.mack && jsi.config.ack_policy !== AckPolicy.None) {
            so.dispatchedFn = autoAckJsMsg;
        }
        if (jsi.callbackFn) {
            so.callback = jsi.callbackFn;
        }
        so.max = jsi.max || 0;
        so.queue = jsi.queue;
        return so;
    }
    async _maybeCreateConsumer(jsi) {
        if (jsi.attached) {
            return;
        }
        if (jsi.isBind) {
            throw new Error(`unable to bind - durable consumer ${jsi.config.durable_name} doesn't exist in ${jsi.stream}`);
        }
        jsi.config = Object.assign({
            deliver_policy: DeliverPolicy.All,
            ack_policy: AckPolicy.Explicit,
            ack_wait: nanos(30 * 1000),
            replay_policy: ReplayPolicy.Instant
        }, jsi.config);
        const ci = await this.consumerAPI.add(jsi.stream, jsi.config);
        if (Array.isArray(jsi.config.filter_subjects && !Array.isArray(ci.config.filter_subjects))) {
            throw new Error(`jetstream server doesn't support consumers with multiple filter subjects`);
        }
        jsi.name = ci.name;
        jsi.config = ci.config;
        jsi.last = ci;
    }
    static ingestionFn(ordered) {
        return (jm, ctx)=>{
            const jsub = ctx;
            if (!jm) return {
                ingest: false,
                protocol: false
            };
            const jmi = jm;
            if (!checkJsError(jmi.msg)) {
                jsub.monitor?.work();
            }
            if (isHeartbeatMsg(jmi.msg)) {
                const ingest = ordered ? jsub._checkHbOrderConsumer(jmi.msg) : true;
                if (!ordered) {
                    jsub.info.flow_control.heartbeat_count++;
                }
                return {
                    ingest,
                    protocol: true
                };
            } else if (isFlowControlMsg(jmi.msg)) {
                jsub.info.flow_control.fc_count++;
                return {
                    ingest: true,
                    protocol: true
                };
            }
            const ingest = ordered ? jsub._checkOrderedConsumer(jm) : true;
            return {
                ingest,
                protocol: false
            };
        };
    }
}
class NatsConnectionImpl {
    options;
    protocol;
    draining;
    listeners;
    _services;
    constructor(opts){
        this.draining = false;
        this.options = parseOptions(opts);
        this.listeners = [];
    }
    static connect(opts = {}) {
        return new Promise((resolve, reject)=>{
            const nc = new NatsConnectionImpl(opts);
            ProtocolHandler.connect(nc.options, nc).then((ph)=>{
                nc.protocol = ph;
                (async function() {
                    for await (const s of ph.status()){
                        nc.listeners.forEach((l)=>{
                            l.push(s);
                        });
                    }
                })();
                resolve(nc);
            }).catch((err)=>{
                reject(err);
            });
        });
    }
    closed() {
        return this.protocol.closed;
    }
    async close() {
        await this.protocol.close();
    }
    _check(subject, sub, pub) {
        if (this.isClosed()) {
            throw NatsError.errorForCode(ErrorCode.ConnectionClosed);
        }
        if (sub && this.isDraining()) {
            throw NatsError.errorForCode(ErrorCode.ConnectionDraining);
        }
        if (pub && this.protocol.noMorePublishing) {
            throw NatsError.errorForCode(ErrorCode.ConnectionDraining);
        }
        subject = subject || "";
        if (subject.length === 0) {
            throw NatsError.errorForCode(ErrorCode.BadSubject);
        }
    }
    publish(subject, data, options) {
        this._check(subject, false, true);
        this.protocol.publish(subject, data, options);
    }
    publishMessage(msg) {
        return this.publish(msg.subject, msg.data, {
            reply: msg.reply,
            headers: msg.headers
        });
    }
    respondMessage(msg) {
        if (msg.reply) {
            this.publish(msg.reply, msg.data, {
                reply: msg.reply,
                headers: msg.headers
            });
            return true;
        }
        return false;
    }
    subscribe(subject, opts = {}) {
        this._check(subject, true, false);
        const sub = new SubscriptionImpl(this.protocol, subject, opts);
        this.protocol.subscribe(sub);
        return sub;
    }
    _resub(s, subject, max) {
        this._check(subject, true, false);
        const si = s;
        si.max = max;
        if (max) {
            si.max = max + si.received;
        }
        this.protocol.resub(si, subject);
    }
    requestMany(subject, data = Empty, opts = {
        maxWait: 1000,
        maxMessages: -1
    }) {
        const asyncTraces = !(this.protocol.options.noAsyncTraces || false);
        try {
            this._check(subject, true, true);
        } catch (err) {
            return Promise.reject(err);
        }
        opts.strategy = opts.strategy || RequestStrategy.Timer;
        opts.maxWait = opts.maxWait || 1000;
        if (opts.maxWait < 1) {
            return Promise.reject(new NatsError("timeout", ErrorCode.InvalidOption));
        }
        const qi = new QueuedIteratorImpl();
        function stop(err) {
            qi.push(()=>{
                qi.stop(err);
            });
        }
        function callback(err, msg) {
            if (err || msg === null) {
                stop(err === null ? undefined : err);
            } else {
                qi.push(msg);
            }
        }
        if (opts.noMux) {
            const stack = asyncTraces ? new Error().stack : null;
            let max = typeof opts.maxMessages === "number" && opts.maxMessages > 0 ? opts.maxMessages : -1;
            const sub = this.subscribe(createInbox(this.options.inboxPrefix), {
                callback: (err, msg)=>{
                    if (msg?.data?.length === 0 && msg?.headers?.status === ErrorCode.NoResponders) {
                        err = NatsError.errorForCode(ErrorCode.NoResponders);
                    }
                    if (err) {
                        if (stack) {
                            err.stack += `\n\n${stack}`;
                        }
                        cancel(err);
                        return;
                    }
                    callback(null, msg);
                    if (opts.strategy === RequestStrategy.Count) {
                        max--;
                        if (max === 0) {
                            cancel();
                        }
                    }
                    if (opts.strategy === RequestStrategy.JitterTimer) {
                        clearTimers();
                        timer = setTimeout(()=>{
                            cancel();
                        }, 300);
                    }
                    if (opts.strategy === RequestStrategy.SentinelMsg) {
                        if (msg && msg.data.length === 0) {
                            cancel();
                        }
                    }
                }
            });
            sub.requestSubject = subject;
            sub.closed.then(()=>{
                stop();
            }).catch((err)=>{
                qi.stop(err);
            });
            const cancel = (err)=>{
                if (err) {
                    qi.push(()=>{
                        throw err;
                    });
                }
                clearTimers();
                sub.drain().then(()=>{
                    stop();
                }).catch((_err)=>{
                    stop();
                });
            };
            qi.iterClosed.then(()=>{
                clearTimers();
                sub?.unsubscribe();
            }).catch((_err)=>{
                clearTimers();
                sub?.unsubscribe();
            });
            try {
                this.publish(subject, data, {
                    reply: sub.getSubject()
                });
            } catch (err) {
                cancel(err);
            }
            let timer = setTimeout(()=>{
                cancel();
            }, opts.maxWait);
            const clearTimers = ()=>{
                if (timer) {
                    clearTimeout(timer);
                }
            };
        } else {
            const rmo = opts;
            rmo.callback = callback;
            qi.iterClosed.then(()=>{
                r.cancel();
            }).catch((err)=>{
                r.cancel(err);
            });
            const r = new RequestMany(this.protocol.muxSubscriptions, subject, rmo);
            this.protocol.request(r);
            try {
                this.publish(subject, data, {
                    reply: `${this.protocol.muxSubscriptions.baseInbox}${r.token}`,
                    headers: opts.headers
                });
            } catch (err) {
                r.cancel(err);
            }
        }
        return Promise.resolve(qi);
    }
    request(subject, data, opts = {
        timeout: 1000,
        noMux: false
    }) {
        try {
            this._check(subject, true, true);
        } catch (err) {
            return Promise.reject(err);
        }
        const asyncTraces = !(this.protocol.options.noAsyncTraces || false);
        opts.timeout = opts.timeout || 1000;
        if (opts.timeout < 1) {
            return Promise.reject(new NatsError("timeout", ErrorCode.InvalidOption));
        }
        if (!opts.noMux && opts.reply) {
            return Promise.reject(new NatsError("reply can only be used with noMux", ErrorCode.InvalidOption));
        }
        if (opts.noMux) {
            const inbox = opts.reply ? opts.reply : createInbox(this.options.inboxPrefix);
            const d = deferred();
            const errCtx = asyncTraces ? new Error() : null;
            const sub = this.subscribe(inbox, {
                max: 1,
                timeout: opts.timeout,
                callback: (err, msg)=>{
                    if (err) {
                        if (errCtx && err.code !== ErrorCode.Timeout) {
                            err.stack += `\n\n${errCtx.stack}`;
                        }
                        sub.unsubscribe();
                        d.reject(err);
                    } else {
                        err = isRequestError(msg);
                        if (err) {
                            if (errCtx) {
                                err.stack += `\n\n${errCtx.stack}`;
                            }
                            d.reject(err);
                        } else {
                            d.resolve(msg);
                        }
                    }
                }
            });
            sub.requestSubject = subject;
            this.protocol.publish(subject, data, {
                reply: inbox,
                headers: opts.headers
            });
            return d;
        } else {
            const r = new RequestOne(this.protocol.muxSubscriptions, subject, opts, asyncTraces);
            this.protocol.request(r);
            try {
                this.publish(subject, data, {
                    reply: `${this.protocol.muxSubscriptions.baseInbox}${r.token}`,
                    headers: opts.headers
                });
            } catch (err) {
                r.cancel(err);
            }
            const p = Promise.race([
                r.timer,
                r.deferred
            ]);
            p.catch(()=>{
                r.cancel();
            });
            return p;
        }
    }
    flush() {
        if (this.isClosed()) {
            return Promise.reject(NatsError.errorForCode(ErrorCode.ConnectionClosed));
        }
        return this.protocol.flush();
    }
    drain() {
        if (this.isClosed()) {
            return Promise.reject(NatsError.errorForCode(ErrorCode.ConnectionClosed));
        }
        if (this.isDraining()) {
            return Promise.reject(NatsError.errorForCode(ErrorCode.ConnectionDraining));
        }
        this.draining = true;
        return this.protocol.drain();
    }
    isClosed() {
        return this.protocol.isClosed();
    }
    isDraining() {
        return this.draining;
    }
    getServer() {
        const srv = this.protocol.getServer();
        return srv ? srv.listen : "";
    }
    status() {
        const iter = new QueuedIteratorImpl();
        iter.iterClosed.then(()=>{
            const idx = this.listeners.indexOf(iter);
            this.listeners.splice(idx, 1);
        });
        this.listeners.push(iter);
        return iter;
    }
    get info() {
        return this.protocol.isClosed() ? undefined : this.protocol.info;
    }
    async context() {
        const r = await this.request(`$SYS.REQ.USER.INFO`);
        return r.json((key, value)=>{
            if (key === "time") {
                return new Date(Date.parse(value));
            }
            return value;
        });
    }
    stats() {
        return {
            inBytes: this.protocol.inBytes,
            outBytes: this.protocol.outBytes,
            inMsgs: this.protocol.inMsgs,
            outMsgs: this.protocol.outMsgs
        };
    }
    async jetstreamManager(opts = {}) {
        const adm = new JetStreamManagerImpl(this, opts);
        if (opts.checkAPI !== false) {
            try {
                await adm.getAccountInfo();
            } catch (err) {
                const ne = err;
                if (ne.code === ErrorCode.NoResponders) {
                    ne.code = ErrorCode.JetStreamNotEnabled;
                }
                throw ne;
            }
        }
        return adm;
    }
    jetstream(opts = {}) {
        return new JetStreamClientImpl(this, opts);
    }
    getServerVersion() {
        const info = this.info;
        return info ? parseSemVer(info.version) : undefined;
    }
    async rtt() {
        if (!this.protocol._closed && !this.protocol.connected) {
            throw NatsError.errorForCode(ErrorCode.Disconnect);
        }
        const start = Date.now();
        await this.flush();
        return Date.now() - start;
    }
    get features() {
        return this.protocol.features;
    }
    get services() {
        if (!this._services) {
            this._services = new ServicesFactory(this);
        }
        return this._services;
    }
    reconnect() {
        if (this.isClosed()) {
            return Promise.reject(NatsError.errorForCode(ErrorCode.ConnectionClosed));
        }
        if (this.isDraining()) {
            return Promise.reject(NatsError.errorForCode(ErrorCode.ConnectionDraining));
        }
        return this.protocol.reconnect();
    }
}
class ServicesFactory {
    nc;
    constructor(nc){
        this.nc = nc;
    }
    add(config) {
        try {
            const s = new ServiceImpl(this.nc, config);
            return s.start();
        } catch (err) {
            return Promise.reject(err);
        }
    }
    client(opts, prefix) {
        return new ServiceClientImpl(this.nc, opts, prefix);
    }
}
class KvStoredEntryImpl {
    bucket;
    sm;
    prefixLen;
    constructor(bucket, prefixLen, sm){
        this.bucket = bucket;
        this.prefixLen = prefixLen;
        this.sm = sm;
    }
    get key() {
        return this.sm.subject.substring(this.prefixLen);
    }
    get value() {
        return this.sm.data;
    }
    get delta() {
        return 0;
    }
    get created() {
        return this.sm.time;
    }
    get revision() {
        return this.sm.seq;
    }
    get operation() {
        return this.sm.header.get(kvOperationHdr) || "PUT";
    }
    get length() {
        const slen = this.sm.header.get(JsHeaders.MessageSizeHdr) || "";
        if (slen !== "") {
            return parseInt(slen, 10);
        }
        return this.sm.data.length;
    }
    json() {
        return this.sm.json();
    }
    string() {
        return this.sm.string();
    }
}
class KvJsMsgEntryImpl {
    bucket;
    key;
    sm;
    constructor(bucket, key, sm){
        this.bucket = bucket;
        this.key = key;
        this.sm = sm;
    }
    get value() {
        return this.sm.data;
    }
    get created() {
        return new Date(millis(this.sm.info.timestampNanos));
    }
    get revision() {
        return this.sm.seq;
    }
    get operation() {
        return this.sm.headers?.get(kvOperationHdr) || "PUT";
    }
    get delta() {
        return this.sm.info.pending;
    }
    get length() {
        const slen = this.sm.headers?.get(JsHeaders.MessageSizeHdr) || "";
        if (slen !== "") {
            return parseInt(slen, 10);
        }
        return this.sm.data.length;
    }
    json() {
        return this.sm.json();
    }
    string() {
        return this.sm.string();
    }
}
class JetStreamSubscriptionImpl extends TypedSubscription {
    js;
    monitor;
    constructor(js, subject, opts){
        super(js.nc, subject, opts);
        this.js = js;
        this.monitor = null;
        this.sub.closed.then(()=>{
            if (this.monitor) {
                this.monitor.cancel();
            }
        });
    }
    set info(info) {
        this.sub.info = info;
    }
    get info() {
        return this.sub.info;
    }
    _resetOrderedConsumer(sseq) {
        if (this.info === null || this.sub.isClosed()) {
            return;
        }
        const newDeliver = createInbox(this.js.nc.options.inboxPrefix);
        const nci = this.js.nc;
        nci._resub(this.sub, newDeliver);
        const info = this.info;
        info.config.name = nuid.next();
        info.ordered_consumer_sequence.delivery_seq = 0;
        info.flow_control.heartbeat_count = 0;
        info.flow_control.fc_count = 0;
        info.flow_control.consumer_restarts++;
        info.deliver = newDeliver;
        info.config.deliver_subject = newDeliver;
        info.config.deliver_policy = DeliverPolicy.StartSequence;
        info.config.opt_start_seq = sseq;
        const req = {};
        req.stream_name = this.info.stream;
        req.config = info.config;
        const subj = `${info.api.prefix}.CONSUMER.CREATE.${info.stream}`;
        this.js._request(subj, req, {
            retries: -1
        }).then((v)=>{
            const ci = v;
            const jinfo = this.sub.info;
            jinfo.last = ci;
            this.info.config = ci.config;
            this.info.name = ci.name;
        }).catch((err)=>{
            const nerr = new NatsError(`unable to recreate ordered consumer ${info.stream} at seq ${sseq}`, ErrorCode.RequestError, err);
            this.sub.callback(nerr, {});
        });
    }
    _maybeSetupHbMonitoring() {
        const ns = this.info?.config?.idle_heartbeat || 0;
        if (ns) {
            this._setupHbMonitoring(millis(ns));
        }
    }
    _setupHbMonitoring(millis, cancelAfter = 0) {
        const opts = {
            cancelAfter: 0,
            maxOut: 2
        };
        if (cancelAfter) {
            opts.cancelAfter = cancelAfter;
        }
        const sub = this.sub;
        const handler = (v)=>{
            const msg = newJsErrorMsg(409, `${Js409Errors.IdleHeartbeatMissed}: ${v}`, this.sub.subject);
            const ordered = this.info?.ordered;
            if (!ordered) {
                this.sub.callback(null, msg);
            } else {
                if (!this.js.nc.protocol.connected) {
                    return false;
                }
                const seq = this.info?.ordered_consumer_sequence?.stream_seq || 0;
                this._resetOrderedConsumer(seq + 1);
                this.monitor?.restart();
                return false;
            }
            return !sub.noIterator;
        };
        this.monitor = new IdleHeartbeatMonitor(millis, handler, opts);
    }
    _checkHbOrderConsumer(msg) {
        const rm = msg.headers.get(JsHeaders.ConsumerStalledHdr);
        if (rm !== "") {
            const nci = this.js.nc;
            nci.publish(rm);
        }
        const lastDelivered = parseInt(msg.headers.get(JsHeaders.LastConsumerSeqHdr), 10);
        const ordered = this.info.ordered_consumer_sequence;
        this.info.flow_control.heartbeat_count++;
        if (lastDelivered !== ordered.delivery_seq) {
            this._resetOrderedConsumer(ordered.stream_seq + 1);
        }
        return false;
    }
    _checkOrderedConsumer(jm) {
        const ordered = this.info.ordered_consumer_sequence;
        const sseq = jm.info.streamSequence;
        const dseq = jm.info.deliverySequence;
        if (dseq != ordered.delivery_seq + 1) {
            this._resetOrderedConsumer(ordered.stream_seq + 1);
            return false;
        }
        ordered.delivery_seq = dseq;
        ordered.stream_seq = sseq;
        return true;
    }
    async destroy() {
        if (!this.isClosed()) {
            await this.drain();
        }
        const jinfo = this.sub.info;
        const name = jinfo.config.durable_name || jinfo.name;
        const subj = `${jinfo.api.prefix}.CONSUMER.DELETE.${jinfo.stream}.${name}`;
        await jinfo.api._request(subj);
    }
    async consumerInfo() {
        const jinfo = this.sub.info;
        const name = jinfo.config.durable_name || jinfo.name;
        const subj = `${jinfo.api.prefix}.CONSUMER.INFO.${jinfo.stream}.${name}`;
        const ci = await jinfo.api._request(subj);
        jinfo.last = ci;
        return ci;
    }
}
class JetStreamPullSubscriptionImpl extends JetStreamSubscriptionImpl {
    constructor(js, subject, opts){
        super(js, subject, opts);
    }
    pull(opts = {
        batch: 1
    }) {
        const { stream, config, name } = this.sub.info;
        const consumer = config.durable_name ?? name;
        const args = {};
        args.batch = opts.batch || 1;
        args.no_wait = opts.no_wait || false;
        if ((opts.max_bytes ?? 0) > 0) {
            const fv = this.js.nc.features.get(Feature.JS_PULL_MAX_BYTES);
            if (!fv.ok) {
                throw new Error(`max_bytes is only supported on servers ${fv.min} or better`);
            }
            args.max_bytes = opts.max_bytes;
        }
        let expires = 0;
        if (opts.expires && opts.expires > 0) {
            expires = opts.expires;
            args.expires = nanos(expires);
        }
        let hb = 0;
        if (opts.idle_heartbeat && opts.idle_heartbeat > 0) {
            hb = opts.idle_heartbeat;
            args.idle_heartbeat = nanos(hb);
        }
        if (hb && expires === 0) {
            throw new Error("idle_heartbeat requires expires");
        }
        if (hb > expires) {
            throw new Error("expires must be greater than idle_heartbeat");
        }
        if (this.info) {
            if (this.monitor) {
                this.monitor.cancel();
            }
            if (expires && hb) {
                if (!this.monitor) {
                    this._setupHbMonitoring(hb, expires);
                } else {
                    this.monitor._change(hb, expires);
                }
            }
            const api = this.info.api;
            const subj = `${api.prefix}.CONSUMER.MSG.NEXT.${stream}.${consumer}`;
            const reply = this.sub.subject;
            api.nc.publish(subj, api.jc.encode(args), {
                reply: reply
            });
        }
    }
}
function msgAdapter(iterator, ackTimeout) {
    if (iterator) {
        return iterMsgAdapter(ackTimeout);
    } else {
        return cbMsgAdapter(ackTimeout);
    }
}
function cbMsgAdapter(ackTimeout) {
    return (err, msg)=>{
        if (err) {
            return [
                err,
                null
            ];
        }
        err = checkJsError(msg);
        if (err) {
            return [
                err,
                null
            ];
        }
        return [
            null,
            toJsMsg(msg, ackTimeout)
        ];
    };
}
function iterMsgAdapter(ackTimeout) {
    return (err, msg)=>{
        if (err) {
            return [
                err,
                null
            ];
        }
        const ne = checkJsError(msg);
        if (ne !== null) {
            return [
                hideNonTerminalJsErrors(ne),
                null
            ];
        }
        return [
            null,
            toJsMsg(msg, ackTimeout)
        ];
    };
}
function hideNonTerminalJsErrors(ne) {
    if (ne !== null) {
        switch(ne.code){
            case ErrorCode.JetStream404NoMessages:
            case ErrorCode.JetStream408RequestTimeout:
                return null;
            case ErrorCode.JetStream409:
                if (isTerminal409(ne)) {
                    return ne;
                }
                return null;
            default:
                return ne;
        }
    }
    return null;
}
function autoAckJsMsg(data) {
    if (data) {
        data.ack();
    }
}
function parseInfo(s) {
    const tokens = s.split(".");
    if (tokens.length === 9) {
        tokens.splice(2, 0, "_", "");
    }
    if (tokens.length < 11 || tokens[0] !== "$JS" || tokens[1] !== "ACK") {
        throw new Error(`not js message`);
    }
    const di = {};
    di.domain = tokens[2] === "_" ? "" : tokens[2];
    di.account_hash = tokens[3];
    di.stream = tokens[4];
    di.consumer = tokens[5];
    di.deliveryCount = parseInt(tokens[6], 10);
    di.redeliveryCount = di.deliveryCount;
    di.redelivered = di.deliveryCount > 1;
    di.streamSequence = parseInt(tokens[7], 10);
    di.deliverySequence = parseInt(tokens[8], 10);
    di.timestampNanos = parseInt(tokens[9], 10);
    di.pending = parseInt(tokens[10], 10);
    return di;
}
class JsMsgImpl {
    msg;
    di;
    didAck;
    timeout;
    constructor(msg, timeout){
        this.msg = msg;
        this.didAck = false;
        this.timeout = timeout;
    }
    get subject() {
        return this.msg.subject;
    }
    get sid() {
        return this.msg.sid;
    }
    get data() {
        return this.msg.data;
    }
    get headers() {
        return this.msg.headers;
    }
    get info() {
        if (!this.di) {
            this.di = parseInfo(this.reply);
        }
        return this.di;
    }
    get redelivered() {
        return this.info.deliveryCount > 1;
    }
    get reply() {
        return this.msg.reply || "";
    }
    get seq() {
        return this.info.streamSequence;
    }
    doAck(payload) {
        if (!this.didAck) {
            this.didAck = !this.isWIP(payload);
            this.msg.respond(payload);
        }
    }
    isWIP(p) {
        return p.length === 4 && p[0] === WPI[0] && p[1] === WPI[1] && p[2] === WPI[2] && p[3] === WPI[3];
    }
    async ackAck(opts) {
        opts = opts || {};
        opts.timeout = opts.timeout || this.timeout;
        const d = deferred();
        if (!this.didAck) {
            this.didAck = true;
            if (this.msg.reply) {
                const mi = this.msg;
                const proto = mi.publisher;
                const trace = !(proto.options?.noAsyncTraces || false);
                const r = new RequestOne(proto.muxSubscriptions, this.msg.reply, {
                    timeout: opts.timeout
                }, trace);
                proto.request(r);
                try {
                    proto.publish(this.msg.reply, ACK, {
                        reply: `${proto.muxSubscriptions.baseInbox}${r.token}`
                    });
                } catch (err) {
                    r.cancel(err);
                }
                try {
                    await Promise.race([
                        r.timer,
                        r.deferred
                    ]);
                    d.resolve(true);
                } catch (err) {
                    r.cancel(err);
                    d.reject(err);
                }
            } else {
                d.resolve(false);
            }
        } else {
            d.resolve(false);
        }
        return d;
    }
    ack() {
        this.doAck(ACK);
    }
    nak(millis) {
        let payload = NAK;
        if (millis) {
            payload = StringCodec().encode(`-NAK ${JSON.stringify({
                delay: nanos(millis)
            })}`);
        }
        this.doAck(payload);
    }
    working() {
        this.doAck(WPI);
    }
    next(subj, opts = {
        batch: 1
    }) {
        const args = {};
        args.batch = opts.batch || 1;
        args.no_wait = opts.no_wait || false;
        if (opts.expires && opts.expires > 0) {
            args.expires = nanos(opts.expires);
        }
        const data = JSONCodec().encode(args);
        const payload = DataBuffer.concat(NXT, SPACE, data);
        const reqOpts = subj ? {
            reply: subj
        } : undefined;
        this.msg.respond(payload, reqOpts);
    }
    term(reason = "") {
        let term = TERM;
        if (reason?.length > 0) {
            term = StringCodec().encode(`+TERM ${reason}`);
        }
        this.doAck(term);
    }
    json() {
        return this.msg.json();
    }
    string() {
        return this.msg.string();
    }
}
export { checkJsError as checkJsError, isFlowControlMsg as isFlowControlMsg, isHeartbeatMsg as isHeartbeatMsg };
export { AckPolicy as AckPolicy, AdvisoryKind as AdvisoryKind, ConsumerDebugEvents as ConsumerDebugEvents, ConsumerEvents as ConsumerEvents, DeliverPolicy as DeliverPolicy, DirectMsgHeaders as DirectMsgHeaders, DiscardPolicy as DiscardPolicy, JsHeaders as JsHeaders, KvWatchInclude as KvWatchInclude, ReplayPolicy as ReplayPolicy, RepublishHeaders as RepublishHeaders, RetentionPolicy as RetentionPolicy, StorageType as StorageType, StoreCompression as StoreCompression };
export { consumerOpts as consumerOpts };
const VERSION = "1.30.3";
const LANG = "nats.ws";
class WsTransport {
    version;
    lang;
    closeError;
    connected;
    done;
    socket;
    options;
    socketClosed;
    encrypted;
    peeked;
    yields;
    signal;
    closedNotification;
    constructor(){
        this.version = VERSION;
        this.lang = LANG;
        this.connected = false;
        this.done = false;
        this.socketClosed = false;
        this.encrypted = false;
        this.peeked = false;
        this.yields = [];
        this.signal = deferred();
        this.closedNotification = deferred();
    }
    async connect(server, options) {
        const connected = false;
        const connLock = deferred();
        if (options.tls) {
            connLock.reject(new NatsError("tls", ErrorCode.InvalidOption));
            return connLock;
        }
        this.options = options;
        const u = server.src;
        if (options.wsFactory) {
            const { socket, encrypted } = await options.wsFactory(server.src, options);
            this.socket = socket;
            this.encrypted = encrypted;
        } else {
            this.encrypted = u.indexOf("wss://") === 0;
            this.socket = new WebSocket(u);
        }
        this.socket.binaryType = "arraybuffer";
        this.socket.onopen = ()=>{
            if (this.isDiscarded()) {
                return;
            }
        };
        this.socket.onmessage = (me)=>{
            if (this.isDiscarded()) {
                return;
            }
            this.yields.push(new Uint8Array(me.data));
            if (this.peeked) {
                this.signal.resolve();
                return;
            }
            const t = DataBuffer.concat(...this.yields);
            const pm = extractProtocolMessage(t);
            if (pm !== "") {
                const m = INFO.exec(pm);
                if (!m) {
                    if (options.debug) {
                        console.error("!!!", render(t));
                    }
                    connLock.reject(new Error("unexpected response from server"));
                    return;
                }
                try {
                    const info = JSON.parse(m[1]);
                    checkOptions(info, this.options);
                    this.peeked = true;
                    this.connected = true;
                    this.signal.resolve();
                    connLock.resolve();
                } catch (err) {
                    connLock.reject(err);
                    return;
                }
            }
        };
        this.socket.onclose = (evt)=>{
            if (this.isDiscarded()) {
                return;
            }
            this.socketClosed = true;
            let reason;
            if (this.done) return;
            if (!evt.wasClean) {
                reason = new Error(evt.reason);
            }
            this._closed(reason);
        };
        this.socket.onerror = (e)=>{
            if (this.isDiscarded()) {
                return;
            }
            const evt = e;
            const err = new NatsError(evt.message, ErrorCode.Unknown, new Error(evt.error));
            if (!connected) {
                connLock.reject(err);
            } else {
                this._closed(err);
            }
        };
        return connLock;
    }
    disconnect() {
        this._closed(undefined, true);
    }
    async _closed(err, internal = true) {
        if (this.isDiscarded()) {
            return;
        }
        if (!this.connected) return;
        if (this.done) return;
        this.closeError = err;
        if (!err) {
            while(!this.socketClosed && this.socket.bufferedAmount > 0){
                await delay(100);
            }
        }
        this.done = true;
        try {
            this.socket.close(err ? 1002 : 1000, err ? err.message : undefined);
        } catch (err) {}
        if (internal) {
            this.closedNotification.resolve(err);
        }
    }
    get isClosed() {
        return this.done;
    }
    [Symbol.asyncIterator]() {
        return this.iterate();
    }
    async *iterate() {
        while(true){
            if (this.isDiscarded()) {
                return;
            }
            if (this.yields.length === 0) {
                await this.signal;
            }
            const yields = this.yields;
            this.yields = [];
            for(let i = 0; i < yields.length; i++){
                if (this.options.debug) {
                    console.info(`> ${render(yields[i])}`);
                }
                yield yields[i];
            }
            if (this.done) {
                break;
            } else if (this.yields.length === 0) {
                yields.length = 0;
                this.yields = yields;
                this.signal = deferred();
            }
        }
    }
    isEncrypted() {
        return this.connected && this.encrypted;
    }
    send(frame) {
        if (this.isDiscarded()) {
            return;
        }
        try {
            this.socket.send(frame.buffer);
            if (this.options.debug) {
                console.info(`< ${render(frame)}`);
            }
            return;
        } catch (err) {
            if (this.options.debug) {
                console.error(`!!! ${render(frame)}: ${err}`);
            }
        }
    }
    close(err) {
        return this._closed(err, false);
    }
    closed() {
        return this.closedNotification;
    }
    isDiscarded() {
        if (this.done) {
            this.discard();
            return true;
        }
        return false;
    }
    discard() {
        this.done = true;
        try {
            this.socket?.close();
        } catch (_err) {}
    }
}
function wsUrlParseFn(u, encrypted) {
    const ut = /^(.*:\/\/)(.*)/;
    if (!ut.test(u)) {
        if (typeof encrypted === "boolean") {
            u = `${encrypted === true ? "https" : "http"}://${u}`;
        } else {
            u = `https://${u}`;
        }
    }
    let url = new URL(u);
    const srcProto = url.protocol.toLowerCase();
    if (srcProto === "ws:") {
        encrypted = false;
    }
    if (srcProto === "wss:") {
        encrypted = true;
    }
    if (srcProto !== "https:" && srcProto !== "http") {
        u = u.replace(/^(.*:\/\/)(.*)/gm, "$2");
        url = new URL(`http://${u}`);
    }
    let protocol;
    let port;
    const host = url.hostname;
    const path = url.pathname;
    const search = url.search || "";
    switch(srcProto){
        case "http:":
        case "ws:":
        case "nats:":
            port = url.port || "80";
            protocol = "ws:";
            break;
        case "https:":
        case "wss:":
        case "tls:":
            port = url.port || "443";
            protocol = "wss:";
            break;
        default:
            port = url.port || encrypted === true ? "443" : "80";
            protocol = encrypted === true ? "wss:" : "ws:";
            break;
    }
    return `${protocol}//${host}:${port}${path}${search}`;
}
function connect(opts = {}) {
    setTransportFactory({
        defaultPort: 443,
        urlParseFn: wsUrlParseFn,
        factory: ()=>{
            return new WsTransport();
        }
    });
    return NatsConnectionImpl.connect(opts);
}
export { connect as connect };
