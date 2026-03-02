package com.shopweb.config;

import com.shopweb.model.entity.Role;
import com.shopweb.repository.RoleRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.List;

@Component
public class DataInitializer implements CommandLineRunner {

  @Autowired
  private RoleRepository roleRepository;

  @Override
  public void run(String... args) throws Exception {
    List<String> roles = Arrays.asList("ROLE_CUSTOMER", "ROLE_STAFF", "ROLE_MANAGER", "ROLE_ADMIN");

    for (String roleName : roles) {
      if (roleRepository.findByName(roleName).isEmpty()) {
        Role role = new Role();
        role.setName(roleName);
        roleRepository.save(role);
        System.out.println("Inserted role: " + roleName);
      }
    }
  }
}
