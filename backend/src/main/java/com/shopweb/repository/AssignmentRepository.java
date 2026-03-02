package com.shopweb.repository;

import com.shopweb.model.entity.Assignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
/**
 * Repository for Assignment entity
 */
@Repository
public interface AssignmentRepository extends JpaRepository<Assignment, Long> {
    // Tìm task theo ID nhân viên
    List<Assignment> findByStaffId(Long staffId);
    
    // Tìm task theo ID nhân viên và trạng thái (nếu cần)
    List<Assignment> findByStaffIdAndStatus(Long staffId, String status);
}