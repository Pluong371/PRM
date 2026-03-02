package com.shopweb.repository;

import com.shopweb.model.entity.Order;
import com.shopweb.model.enums.OrderStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {

        List<Order> findByStatus(OrderStatus status);

        @Query("SELECT o FROM Order o JOIN FETCH o.orderItems oi JOIN FETCH oi.product p WHERE o.user.username = :username AND o.id = :orderId")
        Optional<Order> findByCustomerUsernameAndId(@Param("username") String username, @Param("orderId") Long orderId);

        @Query("SELECT o FROM Order o JOIN FETCH o.orderItems oi JOIN FETCH oi.product p WHERE o.id = :orderId")
        Optional<Order> findByIdWithItems(@Param("orderId") Long orderId);

        @Query("SELECT o FROM Order o JOIN FETCH o.orderItems oi JOIN FETCH oi.product p WHERE o.status = :status")
        List<Order> findByStatusWithItems(@Param("status") OrderStatus status);

        // dùng @Query vì JPA không tự map được user.id
        @Query("SELECT o FROM Order o WHERE o.user.id = :userId")
        List<Order> findByUserId(@Param("userId") Long userId);

        @Query("SELECT o FROM Order o WHERE o.user.username = :username")
        List<Order> findByCustomerUsername(@Param("username") String username);

        // Iter2: search + filter + sort
        // query chung cho search, keyword null = không filter
        @Query("SELECT o FROM Order o WHERE " +
                        "(:keyword IS NULL OR " +
                        "  (:searchField = 'id'    AND CAST(o.id AS string) LIKE %:keyword%) OR " +
                        "  (:searchField = 'name'  AND LOWER(o.user.fullName) LIKE LOWER(CONCAT('%', :keyword, '%'))) OR "
                        +
                        "  (:searchField = 'email' AND LOWER(o.user.email)    LIKE LOWER(CONCAT('%', :keyword, '%')))" +
                        ") " +
                        "AND (:status IS NULL OR o.status = :status)")
        Page<Order> searchOrders(
                        @Param("keyword") String keyword,
                        @Param("searchField") String searchField,
                        @Param("status") OrderStatus status,
                        Pageable pageable);

        // đếm kết quả khớp với filter hiện tại
        @Query("SELECT COUNT(o) FROM Order o WHERE " +
                        "(:keyword IS NULL OR " +
                        "  (:searchField = 'id'    AND CAST(o.id AS string) LIKE %:keyword%) OR " +
                        "  (:searchField = 'name'  AND LOWER(o.user.fullName) LIKE LOWER(CONCAT('%', :keyword, '%'))) OR "
                        +
                        "  (:searchField = 'email' AND LOWER(o.user.email)    LIKE LOWER(CONCAT('%', :keyword, '%')))" +
                        ") " +
                        "AND (:status IS NULL OR o.status = :status)")
        Long countOrders(
                        @Param("keyword") String keyword,
                        @Param("searchField") String searchField,
                        @Param("status") OrderStatus status);

        // sort status phải dùng query riêng vì JPA sort enum theo ordinal, không theo
        // alphabet
        @Query("SELECT o FROM Order o WHERE " +
                        "(:keyword IS NULL OR " +
                        "  (:searchField = 'id'    AND CAST(o.id AS string) LIKE %:keyword%) OR " +
                        "  (:searchField = 'name'  AND LOWER(o.user.fullName) LIKE LOWER(CONCAT('%', :keyword, '%'))) OR "
                        +
                        "  (:searchField = 'email' AND LOWER(o.user.email)    LIKE LOWER(CONCAT('%', :keyword, '%')))" +
                        ") " +
                        "AND (:status IS NULL OR o.status = :status) " +
                        "ORDER BY o.status ASC")
        Page<Order> searchOrdersSortByStatusAsc(
                        @Param("keyword") String keyword,
                        @Param("searchField") String searchField,
                        @Param("status") OrderStatus status,
                        Pageable pageable);

        // giống trên nhưng DESC
        @Query("SELECT o FROM Order o WHERE " +
                        "(:keyword IS NULL OR " +
                        "  (:searchField = 'id'    AND CAST(o.id AS string) LIKE %:keyword%) OR " +
                        "  (:searchField = 'name'  AND LOWER(o.user.fullName) LIKE LOWER(CONCAT('%', :keyword, '%'))) OR "
                        +
                        "  (:searchField = 'email' AND LOWER(o.user.email)    LIKE LOWER(CONCAT('%', :keyword, '%')))" +
                        ") " +
                        "AND (:status IS NULL OR o.status = :status) " +
                        "ORDER BY o.status DESC")
        Page<Order> searchOrdersSortByStatusDesc(
                        @Param("keyword") String keyword,
                        @Param("searchField") String searchField,
                        @Param("status") OrderStatus status,
                        Pageable pageable);

        // đếm theo status cụ thể trong kết quả search hiện tại
        @Query("SELECT COUNT(o) FROM Order o WHERE " +
                        "(:keyword IS NULL OR " +
                        "  (:searchField = 'id'    AND CAST(o.id AS string) LIKE %:keyword%) OR " +
                        "  (:searchField = 'name'  AND LOWER(o.user.fullName) LIKE LOWER(CONCAT('%', :keyword, '%'))) OR "
                        +
                        "  (:searchField = 'email' AND LOWER(o.user.email)    LIKE LOWER(CONCAT('%', :keyword, '%')))" +
                        ") " +
                        "AND o.status = :status")
        Long countOrdersByStatus(
                        @Param("keyword") String keyword,
                        @Param("searchField") String searchField,
                        @Param("status") OrderStatus status);

        // đếm theo từng status, dùng cho các badge CREATED/PAID/... ở UI
        Long countByStatus(OrderStatus status);
}