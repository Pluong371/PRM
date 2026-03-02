package com.shopweb.controller.staff;

import com.shopweb.dto.staff.*;
import com.shopweb.service.staff.StaffSaleService;
import jakarta.validation.Valid;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/**
 * Controller for staff sale operations
 * Handles order management for sale staff
 */
@RestController
@RequestMapping("/api/staff/sales")
@RequiredArgsConstructor
@Slf4j
@PreAuthorize("hasAnyRole('STAFF', 'ADMIN', 'MANAGER')")
public class StaffSaleController {
    
    private final StaffSaleService staffSaleService;
    
    @GetMapping("/orders")
    public ResponseEntity<Page<OrderDTO>> getAllOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        
        log.info("REST request to get all orders - page: {}, size: {}", page, size);
        Page<OrderDTO> orders = staffSaleService.getAllOrders(page, size);
        return ResponseEntity.ok(orders);
    }

    @GetMapping("/orders/{orderId}")
    public ResponseEntity<OrderDetailDTO> getOrderDetail(@PathVariable Long orderId) {
        log.info("REST request to get order detail: {}", orderId);
        OrderDetailDTO orderDetail = staffSaleService.getOrderDetail(orderId);
        return ResponseEntity.ok(orderDetail);
    }
    
    @PutMapping("/orders/{orderId}/status")
    public ResponseEntity<OrderDetailDTO> updateOrderStatus(
            @PathVariable Long orderId,
            @Valid @RequestBody UpdateOrderStatusDTO request) {
        
        log.info("REST request to update order status - orderId: {}, status: {}", 
                 orderId, request.getStatus());
        OrderDetailDTO updatedOrder = staffSaleService.updateOrderStatus(orderId, request);
        return ResponseEntity.ok(updatedOrder);
    }


// ===== ITER2: SEARCH + SORT =====
    @GetMapping("/orders/search")
    public ResponseEntity<Page<OrderDTO>> searchOrders(
        @RequestParam(required = false) String keyword,
        @RequestParam(required = false) String status,
        @RequestParam(defaultValue = "id") String searchField,
        @RequestParam(defaultValue = "id") String sortBy,
        @RequestParam(defaultValue = "asc") String sortDir,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size) {

        OrderSearchDTO req = OrderSearchDTO.builder()
            .keyword(keyword)
            .searchField(searchField)
            .status(status)
            .sortBy(sortBy)
            .sortDir(sortDir)
            .page(page)
            .size(size)
            .build();

        return ResponseEntity.ok(staffSaleService.searchOrders(req));
    }

    // ===== ITER2: COUNT =====
    @GetMapping("/orders/count")
    public ResponseEntity<OrderCountDTO> getOrderCount(
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "id") String searchField,
            @RequestParam(required = false) String status) {

            return ResponseEntity.ok(staffSaleService.getOrderCount(keyword, searchField, status));

    }

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<ErrorResponse> handleRuntimeException(RuntimeException ex) {
        log.error("Error occurred: ", ex);
        ErrorResponse error = new ErrorResponse(
            "ERROR",
            ex.getMessage(),
            System.currentTimeMillis()
        );
        return ResponseEntity.badRequest().body(error);
    }
    

    @Getter
    @Setter
    @AllArgsConstructor
    public static class ErrorResponse {
        private String error;
        private String message;
        private long timestamp;
    }

    @Getter
    @Setter
    @AllArgsConstructor
    public static class MessageResponse {
        private String message;
    }
}