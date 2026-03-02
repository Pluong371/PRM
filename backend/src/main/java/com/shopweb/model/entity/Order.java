package com.shopweb.model.entity;

import com.fasterxml.jackson.annotation.JsonManagedReference;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.ArrayList;

@Entity
@Table(name = "orders")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "customer_id", nullable = false)
    private User user;

    // --- THÊM ĐOẠN NÀY QUAN TRỌNG NHẤT ---
    // mappedBy = "order" nghĩa là bên OrderItem có biến tên là 'order'
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, fetch = FetchType.EAGER)
    @JsonManagedReference
    private List<OrderItem> orderItems = new ArrayList<>();
    // --------------------------------------

    @Column(name = "total_price")
    private BigDecimal totalPrice;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private com.shopweb.model.enums.OrderStatus status; // PENDING, PROCESSING, SHIPPED, DELIVERED, CANCELLED

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_method")
    private com.shopweb.model.enums.PaymentMethod paymentMethod;

    @Column(name = "has_installation")
    private Boolean hasInstallation = false;

    @Column(name = "shipping_address")
    private String shippingAddress;

    @Column(name = "receiver_name")
    private String receiverName;

    @Column(name = "receiver_phone")
    private String receiverPhone;

    @Column(name = "note")
    private String note;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
    // ... các trường cũ

    @Column(name = "cancel_reason")
    private String cancelReason;

    @Column(name = "payment_proof_url")
    private String paymentProofUrl; // URL ảnh bill chuyển khoản (QR payment)
}