package com.shopweb.model.entity.dto;

import lombok.Data;

@Data
public class ProfileResponse {
    private String username;
    private String fullName;
    private String email;
    private String phoneNumber;
}