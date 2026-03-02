package com.shopweb.repository;

import com.shopweb.model.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * Repository for Product entity
 */
@Repository
public interface ProductRepository
        extends JpaRepository<Product, Long>,
        org.springframework.data.jpa.repository.JpaSpecificationExecutor<Product> {

    @org.springframework.data.jpa.repository.Query("SELECT DISTINCT p.brand FROM Product p WHERE p.brand IS NOT NULL")
    java.util.List<String> findDistinctBrands();

    @org.springframework.data.jpa.repository.Query("SELECT p FROM Product p WHERE p.stockQuantity <= p.minStock AND p.minStock > 0")
    java.util.List<Product> findLowStockProducts();
}
