"""Deterministic opt-in direct-API authorization candidates; no runtime cutover."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
from render_account_security import ROOT, PROFILE, replace_once

OVERLAY=PROFILE/'generation/trading-security'
SERVICES={'trade-service':'finos.traderx.tradeservice','order-matcher':'finos.traderx.ordermatcher','trade-processor':'finos.traderx.tradeprocessor'}


def matcher(source):
    source=replace_once(source,'    private final OrderRepository orderRepository;',
        '''    private final finos.traderx.ordermatcher.security.AcceptedOrderAuthority acceptedAuthority;
    private final finos.traderx.ordermatcher.security.TradingAccess tradingAccess;
    private final OrderRepository orderRepository;''')
    source=replace_once(source,'        RestTemplate restTemplate,',
        '''        RestTemplate restTemplate,
        finos.traderx.ordermatcher.security.AcceptedOrderAuthority acceptedAuthority,
        finos.traderx.ordermatcher.security.TradingAccess tradingAccess,''')
    source=replace_once(source,'        this.orderRepository = orderRepository;',
        '''        this.acceptedAuthority = acceptedAuthority;
        this.tradingAccess = tradingAccess;
        this.orderRepository = orderRepository;''')
    source=replace_once(source,'            OrderRecord saved = orderRepository.save(order);',
        '            acceptedAuthority.accept(order);\n            OrderRecord saved = orderRepository.save(order);')
    source=replace_once(source,'            OrderRecord order = findOrder(orderId);\n            if (isOpen(order)) {',
        '            OrderRecord order = findOrder(orderId);\n            tradingAccess.requireTrade(order.getAccountId());\n            if (isOpen(order)) {')
    source=replace_once(source,'''        int remaining = order.getRemainingQuantity();
        int fillQty = remaining < fillFullThreshold ? remaining : Math.max(1, (remaining + 1) / 2);
''','')
    source=replace_once(source,'            if (!submitTrade(liveOrder, fillQty)) {',
        '''            if (!isInTheMoney(liveOrder, marketPrice)) return;
            int remaining = liveOrder.getRemainingQuantity();
            int fillQty = remaining < fillFullThreshold ? remaining : Math.max(1, remaining / 2 + remaining % 2);
            if (!submitTrade(liveOrder, fillQty)) {''')
    source=replace_once(source,'''                liveOrder.setUpdatedAt(Instant.now());
                orderRepository.save(liveOrder);
''','')
    start=source.index('    private boolean submitTrade(OrderRecord order, int quantity) {')
    end=source.index('    private boolean filterByStatus(',start)
    source=source[:start]+'''    private boolean submitTrade(OrderRecord order, int quantity) {
        try {
            acceptedAuthority.requireEligible(order);
            if (quantity <= 0 || quantity > order.getRemainingQuantity()) return false;
            // Fail closed until the authenticated, idempotent execution handoff is implemented.
            // Never send an accepted order through the inherited anonymous POST /trade/ path.
            return false;
        } catch (org.springframework.security.access.AccessDeniedException denied) {
            return false;
        }
    }

'''+source[end:]
    return source


def controller(source,service):
    package=SERVICES[service]
    source=source.replace('import org.springframework.web.bind.annotation.RestController;',
        'import org.springframework.web.bind.annotation.RestController;\nimport '+package+'.security.TradingAccess;')
    if service=='trade-service':
        source=replace_once(source,'  private final Publisher<TradeOrder> tradePublisher;',
            '  private final TradingAccess access;\n  private final Publisher<TradeOrder> tradePublisher;')
        source=replace_once(source,'TradeOrderController(Publisher<TradeOrder> tradePublisher)',
            'TradeOrderController(Publisher<TradeOrder> tradePublisher, TradingAccess access)')
        source=replace_once(source,'    this.tradePublisher = tradePublisher;',
            '    this.access = access;\n    this.tradePublisher = tradePublisher;')
        source=replace_once(source,'    log.info("Called createTradeOrder");',
            '    access.requireTrade(tradeOrder.getAccountId());\n    log.info("Called createTradeOrder");')
        source=replace_once(source,'this.restTemplate.getForEntity(url, Account.class)',
            'this.restTemplate.exchange(url, org.springframework.http.HttpMethod.GET,\n          new org.springframework.http.HttpEntity<Void>(accountHeaders()), Account.class)')
        source=replace_once(source,'  private boolean validateAccount(Integer id) {',
            '''  private org.springframework.http.HttpHeaders accountHeaders() {
    var headers = new org.springframework.http.HttpHeaders();
    headers.setBearerAuth(access.bearerToken());
    return headers;
  }

  private boolean validateAccount(Integer id) {''')
    else:
        source=replace_once(source,'    private final OrderMatcherService orderMatcherService;',
            '    private final TradingAccess access;\n    private final OrderMatcherService orderMatcherService;')
        source=replace_once(source,'OrderController(OrderMatcherService orderMatcherService)',
            'OrderController(OrderMatcherService orderMatcherService, TradingAccess access)')
        source=replace_once(source,'        this.orderMatcherService = orderMatcherService;',
            '        this.access = access;\n        this.orderMatcherService = orderMatcherService;')
        source=replace_once(source,'        return orderMatcherService.listOrders(status, accountId);',
            '''        var allowed = access.accounts();
        if (accountId != null) access.requireAccount(accountId);
        return orderMatcherService.listOrders(status, accountId).stream()
            .filter(order -> allowed.contains(order.getAccountId())).toList();''')
        source=replace_once(source,'        return orderMatcherService.getOrder(orderId);',
            '''        access.accounts();
        OrderResponse order = orderMatcherService.getOrder(orderId);
        access.requireAccount(order.getAccountId());
        return order;''')
        source=replace_once(source,'        OrderResponse response = orderMatcherService.createOrder(request);',
            '        access.requireTrade(request.getAccountId());\n        OrderResponse response = orderMatcherService.createOrder(request);')
        source=replace_once(source,'        OrderResponse response = orderMatcherService.cancelOrder(orderId);',
            '''        access.requireTrader();
        access.requireAccount(orderMatcherService.getOrder(orderId).getAccountId());
        OrderResponse response = orderMatcherService.cancelOrder(orderId);''')
        source=replace_once(source,'        OrderResponse response = orderMatcherService.forceFillOrder(orderId);\n        orderMatcherService.publishOrderUpdate(response);\n        return response;',
            '        throw new org.springframework.security.access.AccessDeniedException("Forbidden");')
    return source


def security(service):
    source=(PROFILE/'generation/account-security/AccountSecurity.java').read_text()
    source=source.replace('finos.traderx.accountservice',SERVICES[service]).replace('AccountSecurity','TradingSecurity').replace('accountChain(HttpSecurity http)','tradingChain(HttpSecurity http, TradingAccess access)')
    old='''            .requestMatchers(HttpMethod.GET, "/account/", "/account/*", "/accountuser/", "/accountuser/*").authenticated()'''
    if service=='trade-processor':
        source=source.replace('tradingChain(HttpSecurity http, TradingAccess access)', 'tradingChain(HttpSecurity http, @Value("${lab.execution.matcher-subject}") String matcherSubject)')
        source=source.replace('    URI uri = URI.create(issuer);', '    if (!"traderx-execution".equals(audience)) throw new IllegalArgumentException("Dedicated execution audience required");\n    URI uri = URI.create(issuer);')
        source=source.replace('    http.csrf', '    if (matcherSubject.isBlank()) throw new IllegalArgumentException("Matcher subject required");\n    http.csrf')
        source=source.replace('.authorizeHttpRequests(auth -> auth', '.authorizeHttpRequests(auth -> auth\n            .dispatcherTypeMatchers(jakarta.servlet.DispatcherType.ERROR).permitAll()')
        return replace_once(source,old,'''            .requestMatchers(HttpMethod.POST, "/internal/executions/*")
                .access((authentication, context) -> new org.springframework.security.authorization.AuthorizationDecision(
                    authentication.get() instanceof org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken jwt
                    && jwt.isAuthenticated() && matcherSubject.equals(jwt.getToken().getSubject())))''')
    operator='"/system/health", "/metrics", "/actuator/prometheus"'
    if service=='order-matcher':operator+=', "/health", "/healthz", "/orders/open-count"'
    routes=f'''            .requestMatchers(HttpMethod.GET, {operator})
                .access((authentication, context) -> new org.springframework.security.authorization.AuthorizationDecision(access.isOperator()))'''
    if service=='trade-service':routes+='\n            .requestMatchers(HttpMethod.POST, "/trade/").authenticated()'
    else:routes+='''
            .requestMatchers(HttpMethod.GET, "/orders", "/orders/*").authenticated()
            .requestMatchers(HttpMethod.POST, "/orders", "/orders/*/cancel").authenticated()'''
    return replace_once(source,old,routes)


def render(target,service):
    if service not in SERVICES:raise ValueError('Unsupported security candidate')
    baseline=json.loads((PROFILE/'baseline.lock.json').read_text());commit=baseline['generated_commit']
    data=subprocess.run(['git','archive',commit,service],cwd=ROOT,check=True,capture_output=True,timeout=30).stdout
    target.mkdir(parents=True,exist_ok=False)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            if member.isfile():
                relative=Path(member.name).relative_to(service)
                if '..' in relative.parts:raise ValueError('Invalid archive member')
                destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True)
                destination.write_bytes(archive.extractfile(member).read());destination.chmod(member.mode & 0o777)
    package=target/'src/main/java'/SERVICES[service].replace('.','/')
    name='TradeOrderController' if service=='trade-service' else 'OrderController'
    if service!='trade-processor':
        path=package/'controller'/f'{name}.java';path.write_text(controller(path.read_text(),service))
    else:
        config=package/'PubSubConfig.java'
        source=config.read_text()
        start=source.index('  @Bean\n  public Subscriber<TradeOrder> tradeFeedHandler()')
        config.write_text(replace_once(source[:start]+'}\n','@Configuration\n',''))
        for relative,annotation in [('controller/TradeServiceController.java','@RestController'),('controller/SystemController.java','@RestController'),('service/TradeService.java','@Service')]:
            legacy=package/relative
            legacy.write_text(replace_once(legacy.read_text(),annotation+'\n',''))

    # Authenticated clients use the same-origin session boundary; no inherited wildcard CORS.
    for path in (package/'config').glob('*Cors*.java'):path.unlink()
    dest=package/'security';dest.mkdir()
    if service!='trade-processor': (dest/'TradingAccess.java').write_text((OVERLAY/'TradingAccess.java').read_text().replace('__PACKAGE__',SERVICES[service]))
    (dest/'TradingSecurity.java').write_text(security(service))
    if service=='trade-processor':
        (dest/'ExecutionController.java').write_text((OVERLAY/'ExecutionController.java').read_text().replace('__PACKAGE__',SERVICES[service]))
    if service=='order-matcher':
        (dest/'AcceptedOrderAuthority.java').write_text((OVERLAY/'AcceptedOrderAuthority.java').read_text().replace('__PACKAGE__',SERVICES[service]))
        model=package/'model/OrderRecord.java'
        model.write_text(replace_once(model.read_text(),'    @PrePersist', '''    @Column(name = "AcceptedSubject", length = 255)
    private String acceptedSubject;
    @Column(name = "AcceptedIssuer", length = 512)
    private String acceptedIssuer;
    @Column(name = "AcceptedTerms", length = 512)
    private String acceptedTerms;
    public String getAcceptedSubject() { return acceptedSubject; }
    public void setAcceptedSubject(String value) { acceptedSubject = value; }
    public String getAcceptedIssuer() { return acceptedIssuer; }
    public void setAcceptedIssuer(String value) { acceptedIssuer = value; }
    public String getAcceptedTerms() { return acceptedTerms; }
    public void setAcceptedTerms(String value) { acceptedTerms = value; }

    @PrePersist'''))
        service_path=package/'service/OrderMatcherService.java'
        service_path.write_text(matcher(service_path.read_text()))
    tests=target/'src/test/java'/SERVICES[service].replace('.','/')/'security';tests.mkdir(parents=True,exist_ok=True)
    for source in (OVERLAY/'tests').glob('*.java'):
        if service=='trade-processor' and source.name not in ('SecurityTestSupport.java','ProcessorApiSecurityTest.java'):continue
        if source.name.startswith('Processor') and service!='trade-processor':continue
        if source.name.startswith('TradeApi') and service!='trade-service':continue
        if source.name.startswith('Order') and service!='order-matcher':continue
        (tests/source.name).write_text(source.read_text().replace('__PACKAGE__',SERVICES[service]))
    if service=='order-matcher':
        inherited=target/'src/test/java/finos/traderx/ordermatcher/OrderMatcherApplicationTests.java'
        inherited.write_text(replace_once(inherited.read_text(),'@SpringBootTest(properties = {',
            '@org.springframework.test.context.ContextConfiguration(initializers=finos.traderx.ordermatcher.security.SecurityTestSupport.Trust.class)\n@SpringBootTest(properties = {'))
    build=target/'build.gradle';build.write_text(replace_once(build.read_text(),'dependencies {',"dependencies {\n  implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'\n  testImplementation 'org.springframework.security:spring-security-test'"))
    inputs=[Path(__file__).resolve(),PROFILE/'baseline.lock.json',ROOT/'scripts/security-lab/render_account_security.py',PROFILE/'generation/account-security/AccountSecurity.java',*sorted(OVERLAY.rglob('*.java'))]
    manifest={'scope':'Direct API candidate only; background execution and deployed UI cutover not accepted','service':service,'generated_commit':commit,'source_commit':baseline['canonical_source_commit'],
        'inputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
        'files':{str(p.relative_to(target)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(target.rglob('*')) if p.is_file()}}
    (target/'security-generation.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--service',choices=SERVICES,required=True);parser.add_argument('--output-dir',type=Path,required=True);args=parser.parse_args();render(args.output_dir.resolve(),args.service)
