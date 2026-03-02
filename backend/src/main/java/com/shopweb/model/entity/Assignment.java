package com.shopweb.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Assignment entity for Staff subsystem
 * Represents tasks assigned to staff members
 */
@Entity
@Table(name = "assignments")
@Data
public class Assignment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Liên kết với Staff (User)
    @ManyToOne
    @JoinColumn(name = "staff_id")
    private User staff;

    // Liên kết với Order
    @ManyToOne
    @JoinColumn(name = "order_id")
    private Order order;

    @Column(name = "task_type")
    private String taskType; // Ví dụ: "PICKING", "PACKING", "DELIVERY"

    @Column(name = "status")
    private String status; // Ví dụ: "PENDING", "IN_PROGRESS", "COMPLETED"

    @Column(name = "assigned_at")
    private LocalDateTime assignedAt;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;
    
    @Column(name = "notes")
    private String notes;
}