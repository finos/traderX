package finos.traderx.ordermatcher.controller;

import finos.traderx.ordermatcher.api.OrderCreateRequest;
import finos.traderx.ordermatcher.api.OrderResponse;
import finos.traderx.ordermatcher.service.OrderMatcherService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/")
public class OrderController {
    private final OrderMatcherService orderMatcherService;

    public OrderController(OrderMatcherService orderMatcherService) {
        this.orderMatcherService = orderMatcherService;
    }

    @GetMapping("/orders")
    public List<OrderResponse> listOrders(
        @RequestParam(value = "status", required = false, defaultValue = "open") String status,
        @RequestParam(value = "accountId", required = false) Integer accountId
    ) {
        return orderMatcherService.listOrders(status, accountId);
    }

    @GetMapping("/orders/{orderId}")
    public OrderResponse getOrder(@PathVariable("orderId") String orderId) {
        return orderMatcherService.getOrder(orderId);
    }

    @PostMapping("/orders")
    @ResponseStatus(HttpStatus.CREATED)
    public OrderResponse createOrder(@RequestBody OrderCreateRequest request) {
        OrderResponse response = orderMatcherService.createOrder(request);
        orderMatcherService.publishOrderUpdate(response);
        return response;
    }

    @PostMapping("/orders/{orderId}/cancel")
    public OrderResponse cancelOrder(@PathVariable("orderId") String orderId) {
        OrderResponse response = orderMatcherService.cancelOrder(orderId);
        orderMatcherService.publishOrderUpdate(response);
        return response;
    }

    @PostMapping("/orders/{orderId}/force-fill")
    public OrderResponse forceFillOrder(@PathVariable("orderId") String orderId) {
        OrderResponse response = orderMatcherService.forceFillOrder(orderId);
        orderMatcherService.publishOrderUpdate(response);
        return response;
    }
}
