package com.shopweb.controller.admin;

import com.shopweb.model.entity.SystemConfig;
import com.shopweb.service.SystemConfigService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin/config")
public class AdminConfigController {

  @Autowired
  private SystemConfigService systemConfigService;

  @GetMapping
  public ResponseEntity<List<SystemConfig>> getAllConfigs() {
    return ResponseEntity.ok(systemConfigService.getAllConfigs());
  }

  @PutMapping("/{key}")
  public ResponseEntity<SystemConfig> updateConfig(
      @PathVariable String key,
      @RequestBody Map<String, String> payload) {

    String value = payload.get("configValue");
    String description = payload.get("description");

    if (value == null) {
      return ResponseEntity.badRequest().build();
    }

    SystemConfig updated = systemConfigService.updateConfig(key, value);
    return ResponseEntity.ok(updated);
  }
}
