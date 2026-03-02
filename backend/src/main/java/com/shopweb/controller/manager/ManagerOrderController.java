package com.shopweb.controller.manager;

import com.shopweb.model.entity.Order;
import com.shopweb.model.enums.OrderStatus;
import com.shopweb.model.enums.PaymentMethod;
import com.shopweb.repository.OrderRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Controller for manager order management
 */
@RestController
@RequestMapping("/api/manager/orders")
public class ManagerOrderController {

    @Autowired
    private OrderRepository orderRepository;

    // GET /api/manager/orders - Get all orders
    @GetMapping
    public ResponseEntity<List<Order>> getAllOrders() {
        return ResponseEntity.ok(orderRepository.findAll());
    }

    // GET /api/manager/orders/pending-payment - Orders waiting for payment
    // confirmation (QR + PENDING)
    @GetMapping("/pending-payment")
    public ResponseEntity<List<Order>> getPendingPaymentOrders() {
        List<Order> orders = orderRepository.findAll().stream()
                .filter(o -> o.getStatus() == OrderStatus.PENDING
                        && o.getPaymentMethod() == PaymentMethod.QR_CODE
                        && o.getPaymentProofUrl() != null)
                .toList();
        return ResponseEntity.ok(orders);
    }

    // GET /api/manager/orders/{id} - Get order details
    @GetMapping("/{id}")
    public ResponseEntity<Order> getOrderById(@PathVariable Long id) {
        return orderRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // PUT /api/manager/orders/{id}/confirm-payment → PAID
    @PutMapping("/{id}/confirm-payment")
    public ResponseEntity<?> confirmPayment(@PathVariable Long id) {
        Order order = orderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Order not found"));

        if (order.getStatus() != OrderStatus.PENDING) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Order is not in PENDING status"));
        }

        order.setStatus(OrderStatus.PAID);
        orderRepository.save(order);
        return ResponseEntity.ok(Map.of("message", "Payment confirmed. Order status → PAID"));
    }

    // PUT /api/manager/orders/{id}/reject-payment → CANCELLED
    @PutMapping("/{id}/reject-payment")
    public ResponseEntity<?> rejectPayment(@PathVariable Long id,
            @RequestBody(required = false) Map<String, String> body) {
        Order order = orderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Order not found"));

        order.setStatus(OrderStatus.CANCELLED);
        if (body != null && body.get("reason") != null) {
            order.setCancelReason(body.get("reason"));
        }
        orderRepository.save(order);
        return ResponseEntity.ok(Map.of("message", "Payment rejected. Order cancelled."));
    }

    // PUT /api/manager/orders/{id}/status - Generic status update
    @PutMapping("/{id}/status")
    public ResponseEntity<?> updateStatus(@PathVariable Long id,
            @RequestBody Map<String, String> body) {
        Order order = orderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        try {
            order.setStatus(OrderStatus.valueOf(body.get("status")));
            orderRepository.save(order);
            return ResponseEntity.ok(Map.of("message", "Status updated to " + body.get("status")));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid status: " + body.get("status")));
        }
    }
}
