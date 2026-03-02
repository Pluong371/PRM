package com.shopweb.controller;

import com.shopweb.model.entity.SystemConfig;
import com.shopweb.service.SystemConfigService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/public/config")
public class PublicConfigController {

  @Autowired
  private SystemConfigService systemConfigService;

  @GetMapping
  public ResponseEntity<Map<String, String>> getPublicConfigs() {
    List<SystemConfig> configs = systemConfigService.getAllConfigs();
    Map<String, String> configMap = new HashMap<>();

    for (SystemConfig config : configs) {
      configMap.put(config.getConfigKey(), config.getConfigValue());
    }

    return ResponseEntity.ok(configMap);
  }
}
