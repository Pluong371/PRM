package com.shopweb.service.customer;

import com.shopweb.dto.request.OrderItemRequest;
import com.shopweb.dto.request.OrderRequest;
import com.shopweb.dto.response.OrderItemResponse;
import com.shopweb.dto.response.OrderResponse;
import com.shopweb.model.entity.Order;
import com.shopweb.model.entity.OrderItem;
import com.shopweb.model.entity.Product;
import com.shopweb.model.entity.User;
import com.shopweb.model.enums.OrderStatus;
import com.shopweb.repository.OrderRepository;
import com.shopweb.repository.OrderItemRepository;
import com.shopweb.repository.ProductRepository;
import com.shopweb.repository.UserRepository;
import com.shopweb.service.SystemConfigService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class CustomerOrderService {

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private OrderItemRepository orderItemRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SystemConfigService systemConfigService;

    // ---------------- CREATE ORDER ----------------
    @Transactional
    public Order createOrder(String username, OrderRequest request) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Order order = new Order();
        order.setUser(user);
        order.setReceiverName(request.getReceiverName());
        order.setReceiverPhone(request.getReceiverPhone());
        order.setShippingAddress(request.getShippingAddress());
        order.setNote(request.getNote());
        order.setStatus(OrderStatus.PENDING);

        // Payment method
        if (request.getPaymentMethod() != null) {
            try {
                order.setPaymentMethod(com.shopweb.model.enums.PaymentMethod.valueOf(request.getPaymentMethod()));
            } catch (IllegalArgumentException ignored) {
            }
        }

        // Save payment proof URL for QR orders
        if (request.getPaymentProofUrl() != null) {
            order.setPaymentProofUrl(request.getPaymentProofUrl());
        }

        BigDecimal totalPrice = BigDecimal.ZERO;

        order = orderRepository.save(order);

        for (OrderItemRequest itemRequest : request.getItems()) {
            Product product = productRepository.findById(itemRequest.getProductId())
                    .orElseThrow(() -> new RuntimeException("Product not found: " + itemRequest.getProductId()));

            if (product.getStockQuantity() < itemRequest.getQuantity()) {
                throw new RuntimeException("Insufficient stock for product: " + product.getName());
            }

            product.setStockQuantity(product.getStockQuantity() - itemRequest.getQuantity());
            productRepository.save(product);

            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(order);
            orderItem.setProduct(product);
            orderItem.setQuantity(itemRequest.getQuantity());
            orderItem.setPrice(product.getPrice());

            orderItemRepository.save(orderItem);

            BigDecimal itemTotal = product.getPrice().multiply(BigDecimal.valueOf(itemRequest.getQuantity()));
            totalPrice = totalPrice.add(itemTotal);
        }

        // Fetch configs
        BigDecimal taxRate = new BigDecimal(systemConfigService.getConfigValue("VAT_RATE", "0")); // e.g. 10 for 10%
        BigDecimal shippingFee = new BigDecimal(systemConfigService.getConfigValue("SHIPPING_FEE", "0"));

        BigDecimal taxAmount = totalPrice.multiply(taxRate).divide(new BigDecimal("100"));
        BigDecimal finalTotal = totalPrice.add(taxAmount).add(shippingFee);

        order.setTotalPrice(finalTotal);
        return orderRepository.save(order);
    }

    public Order getOrderById(String username, Long orderId) {
        return orderRepository.findByCustomerUsernameAndId(username, orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
    }

    // ---------------- MAPPER ----------------
    private OrderResponse mapToResponse(Order order) {
        OrderStatus mappedStatus = order.getStatus();

        List<OrderItemResponse> itemResponses = (order.getOrderItems() == null ? List.<OrderItem>of()
                : order.getOrderItems())
                .stream()
                .map((OrderItem item) -> new OrderItemResponse(
                        item.getProduct().getId(),
                        item.getProduct().getName(),
                        item.getProduct().getImageUrl() != null ? item.getProduct().getImageUrl() : "",
                        item.getQuantity(),
                        item.getPrice(),
                        item.getSerialNumber(),
                        item.getWarrantyEndDate()))
                .toList();

        return new OrderResponse(
                order.getId(),
                mappedStatus,
                order.getTotalPrice(),
                order.getCreatedAt(),
                order.getReceiverName(),
                order.getReceiverPhone(),
                order.getShippingAddress(),
                order.getNote(),
                itemResponses);
    }

    // ---------------- GET ORDERS ----------------
    public List<OrderResponse> getOrdersByUsername(String username) {
        List<Order> orders = orderRepository.findByCustomerUsername(username);
        return orders.stream()
                .map(this::mapToResponse)
                .toList();
    }

    public OrderResponse getOrderDetail(Long orderId) {
        Order order = orderRepository.findByIdWithItems(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        return mapToResponse(order);
    }

    public List<OrderResponse> getOrdersByStatus(OrderStatus status) {
        List<Order> orders = orderRepository.findByStatusWithItems(status);
        return orders.stream()
                .map(this::mapToResponse)
                .toList();
    }
}