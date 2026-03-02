package com.shopweb.model.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;

import java.time.LocalDateTime;

@Entity
@Table(name = "system_configurations")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SystemConfig {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "config_key", unique = true, nullable = false, length = 100)
  private String configKey;

  @Column(name = "config_value", nullable = false, length = 1000)
  private String configValue;

  @Column(name = "description", length = 500)
  private String description;

  @Column(name = "updated_at")
  private LocalDateTime updatedAt;

  @PrePersist
  @PreUpdate
  public void setUpdatedAt() {
    this.updatedAt = LocalDateTime.now();
  }
}
