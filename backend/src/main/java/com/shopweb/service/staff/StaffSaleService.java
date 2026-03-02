package com.shopweb.service.staff;

import com.shopweb.model.entity.Order;
import com.shopweb.model.entity.OrderItem;
import com.shopweb.model.entity.Product;
import com.shopweb.model.entity.User;
import com.shopweb.dto.staff.*;
import com.shopweb.repository.*;
import com.shopweb.model.enums.OrderStatus;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.shopweb.model.enums.OrderStatus;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class StaffSaleService {

    private final OrderRepository orderRepos;

    public Page<OrderDTO> getAllOrders(int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.ASC, "id"));
        return orderRepos.findAll(pageable).map(this::convertToOrderDTO);
    }

    public OrderDetailDTO getOrderDetail(Long orderId) {
        // tìm order theo id, nếu không có thì throw lỗi
        Order order = orderRepos.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found: " + orderId));
        return convertToOrderDetailDTO(order);
    }

    @Transactional
    public OrderDetailDTO updateOrderStatus(Long orderId, UpdateOrderStatusDTO request) {
        Order order = orderRepos.findById(orderId)
                .orElseThrow(() -> new RuntimeException("Order not found: " + orderId));

        OrderStatus newStatus = OrderStatus.valueOf(request.getStatus());

        // validate
        com.shopweb.model.enums.OrderStatus newSvtatus = com.shopweb.model.enums.OrderStatus
                .valueOf(request.getStatus());
        validateStatusTransition(order.getStatus(), newStatus);

        order.setStatus(newStatus);
        if (request.getHasInstallation() != null) {
            order.setHasInstallation(request.getHasInstallation());
        }

        return convertToOrderDetailDTO(orderRepos.save(order));
    }

    private void validateStatusTransition(OrderStatus current, OrderStatus next) {
        if (current == OrderStatus.DELIVERED || current == OrderStatus.CANCELLED) {
            throw new RuntimeException("Cannot update status of completed or cancelled order");
        }
    }

    public Page<OrderDTO> searchOrders(OrderSearchDTO req) {
        Sort.Direction direction = "desc".equalsIgnoreCase(req.getSortDir())
                ? Sort.Direction.DESC
                : Sort.Direction.ASC;

        OrderStatus statusEnum = parseStatus(req.getStatus());
        String keyword = blankToNull(req.getKeyword());
        String searchField = req.getSearchField() != null ? req.getSearchField() : "id";
        String sortBy = req.getSortBy() != null ? req.getSortBy() : "id";

        // sort theo status phải dùng query riêng vì JPA sort enum theo ordinal chứ
        // không theo alphabet
        if ("status".equals(sortBy)) {
            Pageable pageable = PageRequest.of(req.getPage(), req.getSize());
            Page<Order> result = direction == Sort.Direction.ASC
                    ? orderRepos.searchOrdersSortByStatusAsc(keyword, searchField, statusEnum, pageable)
                    : orderRepos.searchOrdersSortByStatusDesc(keyword, searchField, statusEnum, pageable);
            return result.map(this::convertToOrderDTO);
        }

        // map sortBy string sang tên field thực trong entity
        String sortField = switch (sortBy) {
            case "createdAt" -> "createdAt";
            case "totalPrice" -> "totalPrice";
            default -> "id";
        };

        Pageable pageable = PageRequest.of(req.getPage(), req.getSize(), Sort.by(direction, sortField));
        return orderRepos.searchOrders(keyword, searchField, statusEnum, pageable)
                .map(this::convertToOrderDTO);
    }

    public OrderCountDTO getOrderCount(String keyword, String searchField, String status) {
        String k = blankToNull(keyword);
        String field = blankToNull(searchField) != null ? searchField : "id";

        Long total = orderRepos.countOrders(k, field, parseStatus(status));

        // đếm từng status theo kết quả search hiện tại
        return OrderCountDTO.builder()
                .total(total)

                .paid(orderRepos.countOrdersByStatus(k, field, OrderStatus.PAID))
                .confirmed(orderRepos.countOrdersByStatus(k, field, OrderStatus.CONFIRMED))

                .failed(orderRepos.countOrdersByStatus(k, field, OrderStatus.FAILED))
                .refunded(orderRepos.countOrdersByStatus(k, field, OrderStatus.REFUNDED))
                .delivered(orderRepos.countOrdersByStatus(k, field, OrderStatus.DELIVERED))
                .completed(orderRepos.countOrdersByStatus(k, field, OrderStatus.COMPLETED))
                .cancelled(orderRepos.countOrdersByStatus(k, field, OrderStatus.CANCELLED))
                .build();
    }

    // parse string -> enum, trả null nếu không hợp lệ (null = không filter)
    private OrderStatus parseStatus(String status) {
        if (status == null || status.isBlank())
            return null;
        try {
            return OrderStatus.valueOf(status.toUpperCase());
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    // chuỗi rỗng/null -> null, để query biết không cần filter keyword
    private String blankToNull(String s) {
        return (s != null && !s.isBlank()) ? s.trim() : null;
    }

    private BigDecimal calculateTotalPrice(List<OrderItem> items) {
        if (items == null || items.isEmpty())
            return BigDecimal.ZERO;
        return items.stream()
                .map(item -> item.getPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private OrderDTO convertToOrderDTO(Order order) {
        return OrderDTO.builder()
                .id(order.getId())
                .customerId(order.getUser().getId())
                .customerName(order.getUser().getFullName())
                .customerEmail(order.getUser().getEmail())
                .totalPrice(calculateTotalPrice(order.getOrderItems()))
                .status(order.getStatus().name())
                .hasInstallation(order.getHasInstallation())
                .shippingAddress(order.getShippingAddress())
                .createdAt(order.getCreatedAt())
                .totalItems(order.getOrderItems() != null ? order.getOrderItems().size() : 0)
                .build();
    }

    private OrderDetailDTO convertToOrderDetailDTO(Order order) {
        User user = order.getUser();

        CustomerInfoDTO customerDTO = CustomerInfoDTO.builder()
                .id(user.getId())
                .username(user.getUsername())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .isActive(user.getIsActive())
                .build();

        List<OrderItemDTO> itemDTOs = order.getOrderItems().stream()
                .map(this::convertToOrderItemDTO)
                .collect(Collectors.toList());

        return OrderDetailDTO.builder()
                .id(order.getId())
                .customer(customerDTO)
                .totalPrice(calculateTotalPrice(order.getOrderItems()))
                .status(order.getStatus().name())
                .hasInstallation(order.getHasInstallation())
                .shippingAddress(order.getShippingAddress())
                .createdAt(order.getCreatedAt())
                .items(itemDTOs)
                .build();
    }

    private OrderItemDTO convertToOrderItemDTO(OrderItem item) {
        Product product = item.getProduct();
        return OrderItemDTO.builder()
                .id(item.getId())
                .productId(product.getId())
                .productName(product.getName())
                .productModel(product.getModel())
                .productBrand(product.getBrand())
                .productImage(product.getImageUrl())
                .quantity(item.getQuantity())
                .priceAtPurchase(item.getPrice())
                .price(item.getPrice())
                .subtotal(item.getPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
                .build();
    }
}