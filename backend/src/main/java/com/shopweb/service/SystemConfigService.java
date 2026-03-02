package com.shopweb.service;

import com.shopweb.model.entity.SystemConfig;
import com.shopweb.repository.SystemConfigRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class SystemConfigService {

  @Autowired
  private SystemConfigRepository systemConfigRepository;

  public List<SystemConfig> getAllConfigs() {
    return systemConfigRepository.findAll();
  }

  public SystemConfig getConfigByKey(String key) {
    return systemConfigRepository.findByConfigKey(key)
        .orElseThrow(() -> new RuntimeException("Configuration key not found: " + key));
  }

  public String getConfigValue(String key, String defaultValue) {
    return systemConfigRepository.findByConfigKey(key)
        .map(SystemConfig::getConfigValue)
        .orElse(defaultValue);
  }

  public SystemConfig updateConfig(String key, String value) {
    System.out.println(key);
    System.out.println(value);

    SystemConfig config = systemConfigRepository.findByConfigKey(key).orElse(null);
    if (config == null) {
      config = SystemConfig.builder()
          .configKey(key)
          .configValue(value)
          .build();
    } else {
      config.setConfigValue(value);

    }
    return systemConfigRepository.save(config);
  }
}
