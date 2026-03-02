package com.shopweb.controller.customer;

import com.shopweb.model.entity.Order;
import com.shopweb.repository.OrderRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import com.shopweb.dto.response.OrderResponse;
import com.shopweb.dto.response.OrderItemResponse;

import java.util.List;

/**
 * Controller for customer order management
 */
@RestController
@RequestMapping("/api/customer/orders")
public class CustomerOrderController {

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private com.shopweb.service.customer.CustomerOrderService customerOrderService;

    // POST /api/customer/orders - Create new order
    @PostMapping
    public ResponseEntity<Order> createOrder(@RequestBody com.shopweb.dto.request.OrderRequest request) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

        String currentUsername = authentication.getName();

        Order newOrder = customerOrderService.createOrder(currentUsername, request);
        return ResponseEntity.ok(newOrder);
    }

    // GET /api/customer/orders - Get customer orders
    @GetMapping
    public ResponseEntity<List<OrderResponse>> getMyOrders() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        String currentUsername = authentication.getName();

        List<Order> orders = orderRepository.findByCustomerUsername(currentUsername);

        List<OrderResponse> responses = orders.stream().map(order -> {

            List<OrderItemResponse> itemResponses = order.getOrderItems().stream()
                    .map(item -> new OrderItemResponse(
                            item.getProduct().getId(),
                            item.getProduct().getName(),
                            item.getProduct().getImageUrl(),
                            item.getQuantity(),
                            item.getPrice(),
                            item.getSerialNumber(),
                            item.getWarrantyEndDate()
                    ))
                    .toList();

            return new OrderResponse(
                    order.getId(),
                    order.getStatus(),
                    order.getTotalPrice(),
                    order.getCreatedAt(),
                    order.getReceiverName(),
                    order.getReceiverPhone(),
                    order.getShippingAddress(),
                    order.getNote(),
                    itemResponses
            );

        }).toList();

        return ResponseEntity.ok(responses);
    }

    // GET /api/customer/orders/{id} - Get order details
    @GetMapping("/{id}")
    public ResponseEntity<Order> getOrderById(@PathVariable Long id) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        String currentUsername = authentication.getName();

        Order order = customerOrderService.getOrderById(currentUsername, id);
        return ResponseEntity.ok(order);
    }

}
