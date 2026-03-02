package com.shopweb.model.entity;

import com.shopweb.model.enums.OtpPurpose;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "otp_verification")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class OtpVerification {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false)
  private String email;

  @Column(nullable = false, name = "otp_code")
  private String otpCode;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private OtpPurpose purpose;

  @Column(name = "created_at", nullable = false)
  private LocalDateTime createdAt;

  @Column(name = "expires_at", nullable = false)
  private LocalDateTime expiresAt;

  @Column(nullable = false)
  private Integer attempts = 0;

  @Column(name = "request_count", nullable = false)
  private Integer requestCount = 1;

  @PrePersist
  protected void onCreate() {
    createdAt = LocalDateTime.now();
    if (expiresAt == null) {
      // Default 5 minutes expiry if not set
      expiresAt = createdAt.plusMinutes(5);
    }
  }
}
