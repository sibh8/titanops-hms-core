package com.medicore.hms.medication.repository;
import com.medicore.hms.medication.model.Medication;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
@Repository
public interface MedicationRepository extends JpaRepository<Medication, Long> {
    List<Medication> findByMedicationNameContainingIgnoreCase(String name);
}
