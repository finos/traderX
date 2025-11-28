package finos.traderx.accountservice.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import com.fasterxml.jackson.databind.ObjectMapper;

import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.Account;
import finos.traderx.accountservice.service.AccountService;

import static org.mockito.Mockito.when;

@WebMvcTest(AccountController.class)
class AccountControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AccountService accountService;

    @Autowired
    private ObjectMapper objectMapper;

    private Account testAccount;
    private List<Account> testAccounts;

    @BeforeEach
    void setUp() {
        testAccount = new Account();
        testAccount.setId(1);
        testAccount.setDisplayName("Test Account");

        testAccounts = new ArrayList<>();
        testAccounts.add(testAccount);
        
        Account account2 = new Account();
        account2.setId(2);
        account2.setDisplayName("Another Account");
        testAccounts.add(account2);
    }

    @Test
    void testGetAllAccounts() throws Exception {
        // Arrange
        when(accountService.getAllAccount()).thenReturn(testAccounts);

        // Act & Assert
        mockMvc.perform(get("/account/")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].id").value(1))
                .andExpect(jsonPath("$[0].displayName").value("Test Account"))
                .andExpect(jsonPath("$[1].id").value(2))
                .andExpect(jsonPath("$[1].displayName").value("Another Account"));
    }

    @Test
    void testGetAccountByValidId() throws Exception {
        // Arrange
        when(accountService.getAccountById(1)).thenReturn(testAccount);

        // Act & Assert
        mockMvc.perform(get("/account/1")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.displayName").value("Test Account"));
    }

    @Test
    void testGetAccountByInvalidId() throws Exception {
        // Arrange
        int invalidId = 999;
        when(accountService.getAccountById(invalidId))
                .thenThrow(new ResourceNotFoundException("Account with id " + invalidId + "not found"));

        // Act & Assert
        mockMvc.perform(get("/account/" + invalidId)
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }

    @Test
    void testCreateNewAccount() throws Exception {
        // Arrange
        Account newAccount = new Account();
        newAccount.setDisplayName("New Account");
        
        Account createdAccount = new Account();
        createdAccount.setId(3);
        createdAccount.setDisplayName("New Account");
        
        when(accountService.upsertAccount(any(Account.class))).thenReturn(createdAccount);

        // Act & Assert
        mockMvc.perform(post("/account/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(newAccount)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(3))
                .andExpect(jsonPath("$.displayName").value("New Account"));
    }

    @Test
    void testUpdateExistingAccount() throws Exception {
        // Arrange
        Account updatedAccount = new Account();
        updatedAccount.setId(1);
        updatedAccount.setDisplayName("Updated Account Name");
        
        when(accountService.upsertAccount(any(Account.class))).thenReturn(updatedAccount);

        // Act & Assert
        mockMvc.perform(put("/account/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updatedAccount)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.displayName").value("Updated Account Name"));
    }
}

