package com.shopweb.controller.staff;

import com.shopweb.model.entity.*;
import com.shopweb.model.enums.OrderStatus;
import com.shopweb.repository.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/staff/picking")
@CrossOrigin(origins = "http://localhost:5173")
public class StaffPickingController {
    @Autowired
    private WarrantyTicketRepository warrantyTicketRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private OrderItemRepository orderItemRepository;

    @GetMapping("/orders")
    public List<Order> getPickingOrders() {
        return orderRepository.findAll().stream()
                .filter(o -> o.getStatus() == OrderStatus.PENDING || o.getStatus() == OrderStatus.PROCESSING)
                .toList();
    }

    @GetMapping("/orders/{id}")
    public ResponseEntity<?> getOrderDetails(@PathVariable Long id) {
        return orderRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/orders/{orderId}/items/{productId}/pick")
    @Transactional
    public ResponseEntity<?> pickItemWithSerial(
            @PathVariable Long orderId,
            @PathVariable Long productId,
            @RequestBody Map<String, String> body) {

        String serialNumber = body.get("serialNumber");
        String warrantyDateStr = body.get("warrantyEndDate");

        Order order = orderRepository.findById(orderId).orElseThrow();
        OrderItem targetItem = order.getOrderItems().stream()
                .filter(item -> item.getProduct().getId().equals(productId))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("Sản phẩm không có trong đơn này"));

        Product product = targetItem.getProduct();
        if (product.getStockQuantity() <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Kho đã hết hàng thực tế!"));
        }

        targetItem.setSerialNumber(serialNumber);
        if (warrantyDateStr != null) {
            targetItem.setWarrantyEndDate(LocalDate.parse(warrantyDateStr).atStartOfDay());
        }
        orderItemRepository.save(targetItem);

        product.setStockQuantity(product.getStockQuantity() - targetItem.getQuantity());
        productRepository.save(product);

        return ResponseEntity.ok(Map.of("message", "Đã lấy hàng & cập nhật bảo hành thành công"));
    }

    @PostMapping("/orders/{id}/cancel")
    public ResponseEntity<?> cancelOrder(@PathVariable Long id, @RequestBody Map<String, String> body) {
        String reason = body.get("reason");
        Order order = orderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy đơn hàng"));

        order.setStatus(OrderStatus.CANCELLED);
        order.setCancelReason(reason);
        orderRepository.save(order);

        return ResponseEntity.ok(Map.of("message", "Đã hủy đơn và báo cáo lý do thành công"));
    }

    @PostMapping("/orders/{id}/confirm")
    public ResponseEntity<?> confirmPicking(@PathVariable Long id) {
        Order order = orderRepository.findById(id).orElseThrow();
        order.setStatus(OrderStatus.SHIPPED);
        orderRepository.save(order);
        return ResponseEntity.ok(Map.of("message", "Đã bàn giao cho Shipper"));
    }

    @GetMapping("/warranty/{serialNumber}")
    public ResponseEntity<?> checkWarranty(@PathVariable String serialNumber) {
        return orderItemRepository.findBySerialNumber(serialNumber)
                .map(item -> {
                    Order order = item.getOrder();
                    Map<String, Object> response = new HashMap<>();
                    response.put("productName", item.getProduct().getName());
                    response.put("serialNumber", item.getSerialNumber());
                    response.put("warrantyEndDate",
                            item.getWarrantyEndDate() != null ? item.getWarrantyEndDate() : "N/A");
                    response.put("customerName", order.getReceiverName());
                    response.put("orderId", order.getId());
                    response.put("purchaseDate", order.getCreatedAt());
                    response.put("status", order.getStatus());

                    return ResponseEntity.ok(response);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    // 7. API TẠO PHIẾU BẢO HÀNH (Khi bấm nút Tiếp Nhận)
    @PostMapping("/warranty")
    public ResponseEntity<?> createWarrantyTicket(@RequestBody Map<String, String> body) {
        String serialNumber = body.get("serialNumber");
        String issueDescription = body.get("issueDescription");

        if (serialNumber == null || serialNumber.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "Thiếu Serial Number"));
        }

        WarrantyTicket ticket = new WarrantyTicket();
        ticket.setSerialNumber(serialNumber);
        ticket.setIssueDescription(issueDescription);
        ticket.setStatus("RECEIVED"); // Trạng thái mặc định: Đã tiếp nhận

        warrantyTicketRepository.save(ticket);

        return ResponseEntity.ok(Map.of(
                "message", "Đã tạo phiếu tiếp nhận thành công!",
                "ticketId", ticket.getId()));
    }

    // 8. LẤY DANH SÁCH PHIẾU BẢO HÀNH ĐANG XỬ LÝ (Chưa hoàn thành)
    @GetMapping("/warranty/active")
    public ResponseEntity<?> getActiveWarrantyTickets() {
        // Lấy tất cả phiếu, sau đó lọc ở Java (hoặc viết Query ở Repo sẽ tối ưu hơn)
        List<WarrantyTicket> tickets = warrantyTicketRepository.findAll().stream()
                .filter(t -> !t.getStatus().equals("RESOLVED") && !t.getStatus().equals("REJECTED"))
                .toList();
        return ResponseEntity.ok(tickets);
    }

    // 9. CẬP NHẬT TRẠNG THÁI PHIẾU (Sửa xong / Hoàn thành)
    @PutMapping("/warranty/{id}/status")
    public ResponseEntity<?> updateTicketStatus(@PathVariable Long id, @RequestBody Map<String, String> body) {
        String newStatus = body.get("status"); // REPAIRED hoặc RESOLVED
        String note = body.get("technicianNote"); // Ghi chú sửa chữa

        WarrantyTicket ticket = warrantyTicketRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy phiếu"));

        ticket.setStatus(newStatus);
        if (note != null) {
            ticket.setTechnicianNote(note);
        }

        warrantyTicketRepository.save(ticket);
        return ResponseEntity.ok(Map.of("message", "Cập nhật trạng thái thành công: " + newStatus));
    }
}