package com.shopweb.model.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "warranty_tickets")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class WarrantyTicket {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "serial_number", nullable = false)
    private String serialNumber;

    @Column(name = "issue_description", columnDefinition = "NVARCHAR(MAX)")
    private String issueDescription;

    @Column(name = "status")
    private String status; // RECEIVED, REJECTED, RESOLVED

    @Column(name = "technician_note", columnDefinition = "NVARCHAR(MAX)")
    private String technicianNote;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (status == null) status = "RECEIVED";
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}