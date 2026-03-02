package com.shopweb.repository;

import com.shopweb.model.entity.Stock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * Repository for Stock entity
 */
@Repository
public interface StockRepository extends JpaRepository<Stock, Long> {
}
