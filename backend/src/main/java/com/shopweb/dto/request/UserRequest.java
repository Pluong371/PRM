package com.shopweb.dto.request;

import lombok.Data;
import java.util.List;

@Data
public class UserRequest {
  private String username;
  private String password;
  private String email;
  private String fullName;
  private String phoneNumber;
  private List<String> roles;
}
