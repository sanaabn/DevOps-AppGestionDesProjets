package tn.esprit.backend.service.impl;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import tn.esprit.backend.entity.Entreprise;
import tn.esprit.backend.repository.EntrepriseRepository;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EntrepriseServiceImplTest {

    @Mock
    private EntrepriseRepository entrepriseRepository;

    @InjectMocks
    private EntrepriseServiceImpl entrepriseService;

    @Test
    void addEntrepriseShouldSaveAndReturnEntreprise() {
        Entreprise entreprise = Entreprise.builder().nom("ESPRIT").adresse("Ariana").build();
        when(entrepriseRepository.save(entreprise)).thenReturn(entreprise);

        Entreprise result = entrepriseService.addEntreprise(entreprise);

        assertSame(entreprise, result);
        verify(entrepriseRepository).save(entreprise);
    }

    @Test
    void updateEntrepriseShouldSaveAndReturnEntreprise() {
        Entreprise entreprise = Entreprise.builder().id(1L).nom("ESPRIT updated").build();
        when(entrepriseRepository.save(entreprise)).thenReturn(entreprise);

        Entreprise result = entrepriseService.updateEntreprise(entreprise);

        assertSame(entreprise, result);
        verify(entrepriseRepository).save(entreprise);
    }

    @Test
    void deleteEntrepriseShouldDeleteById() {
        entrepriseService.deleteEntreprise(1L);

        verify(entrepriseRepository).deleteById(1L);
    }

    @Test
    void getEntrepriseByIdShouldReturnEntrepriseWhenFound() {
        Entreprise entreprise = Entreprise.builder().id(1L).nom("ESPRIT").build();
        when(entrepriseRepository.findById(1L)).thenReturn(Optional.of(entreprise));

        Entreprise result = entrepriseService.getEntrepriseById(1L);

        assertSame(entreprise, result);
        verify(entrepriseRepository).findById(1L);
    }

    @Test
    void getEntrepriseByIdShouldReturnNullWhenNotFound() {
        when(entrepriseRepository.findById(99L)).thenReturn(Optional.empty());

        assertNull(entrepriseService.getEntrepriseById(99L));
    }

    @Test
    void getAllEntreprisesShouldReturnAllEntries() {
        List<Entreprise> entreprises = List.of(
                Entreprise.builder().id(1L).nom("ESPRIT").build(),
                Entreprise.builder().id(2L).nom("Company").build()
        );
        when(entrepriseRepository.findAll()).thenReturn(entreprises);

        List<Entreprise> result = entrepriseService.getAllEntreprises();

        assertSame(entreprises, result);
        assertEquals(2, result.size());
        verify(entrepriseRepository).findAll();
    }
}
