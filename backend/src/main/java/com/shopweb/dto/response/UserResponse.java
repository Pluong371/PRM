package com.shopweb.dto.response;

import com.shopweb.model.entity.Role;
import com.shopweb.model.entity.User;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Data
public class UserResponse {
  private Long id;
  private String username;
  private String email;
  private String fullName;
  private String phoneNumber;
  private Boolean isActive;
  private LocalDateTime createdAt;
  private List<String> roles;

  public static UserResponse fromEntity(User user) {
    UserResponse response = new UserResponse();
    response.setId(user.getId());
    response.setUsername(user.getUsername());
    response.setEmail(user.getEmail());
    response.setFullName(user.getFullName());
    response.setPhoneNumber(user.getPhoneNumber());
    response.setIsActive(user.getIsActive());
    response.setCreatedAt(user.getCreatedAt());
    response.setRoles(user.getRoles().stream()
        .map(Role::getName)
        .collect(Collectors.toList()));
    return response;
  }
}
