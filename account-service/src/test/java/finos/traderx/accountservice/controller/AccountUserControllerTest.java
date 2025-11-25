package finos.traderx.accountservice.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.List;

import java.lang.reflect.Field;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.ApplicationContext;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.databind.ObjectMapper;

import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.AccountUser;
import finos.traderx.accountservice.model.Person;
import finos.traderx.accountservice.service.AccountUserService;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@WebMvcTest(AccountUserController.class)
@TestPropertySource(properties = {"people.service.url=http://localhost:8080"})
class AccountUserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AccountUserService accountUserService;

    private RestTemplate restTemplate;

    @Autowired
    private ApplicationContext applicationContext;

    @Autowired
    private ObjectMapper objectMapper;

    private AccountUser testAccountUser;
    private List<AccountUser> testAccountUsers;
    private Person validPerson;

    @BeforeEach
    void setUp() throws Exception {
        // Create and inject mock RestTemplate into the controller using reflection
        restTemplate = mock(RestTemplate.class);
        AccountUserController controller = applicationContext.getBean(AccountUserController.class);
        Field restTemplateField = AccountUserController.class.getDeclaredField("restTemplate");
        restTemplateField.setAccessible(true);
        restTemplateField.set(controller, restTemplate);

        testAccountUser = new AccountUser();
        testAccountUser.setAccountId(1);
        testAccountUser.setUsername("testuser");

        testAccountUsers = new ArrayList<>();
        testAccountUsers.add(testAccountUser);
        
        AccountUser accountUser2 = new AccountUser();
        accountUser2.setAccountId(1);
        accountUser2.setUsername("anotheruser");
        testAccountUsers.add(accountUser2);

        AccountUser accountUser3 = new AccountUser();
        accountUser3.setAccountId(2);
        accountUser3.setUsername("user3");
        testAccountUsers.add(accountUser3);

        validPerson = new Person();
        validPerson.setLogonId("testuser");
        validPerson.setFullName("Test User");
        validPerson.setEmail("testuser@example.com");
    }

    @Test
    void testGetAllAccountUserMappings() throws Exception {
        // Arrange
        when(accountUserService.getAllAccountUsers()).thenReturn(testAccountUsers);

        // Act & Assert
        mockMvc.perform(get("/accountuser/")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(3))
                .andExpect(jsonPath("$[0].accountId").value(1))
                .andExpect(jsonPath("$[0].username").value("testuser"))
                .andExpect(jsonPath("$[1].accountId").value(1))
                .andExpect(jsonPath("$[1].username").value("anotheruser"))
                .andExpect(jsonPath("$[2].accountId").value(2))
                .andExpect(jsonPath("$[2].username").value("user3"));
    }

    @Test
    void testGetAccountUserByAccountId() throws Exception {
        // Arrange
        // Note: The current endpoint returns a single AccountUser by ID
        // For testing "by Account ID", we'll test with an account ID and verify the returned AccountUser has that account ID
        when(accountUserService.getAccountUserById(1)).thenReturn(testAccountUser);

        // Act & Assert
        mockMvc.perform(get("/accountuser/1")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.accountId").value(1))
                .andExpect(jsonPath("$.username").value("testuser"));
    }

    @Test
    void testCreateAccountUserMappingWithValidUser() throws Exception {
        // Arrange
        AccountUser newAccountUser = new AccountUser();
        newAccountUser.setAccountId(1);
        newAccountUser.setUsername("validuser");

        AccountUser createdAccountUser = new AccountUser();
        createdAccountUser.setAccountId(1);
        createdAccountUser.setUsername("validuser");

        // Mock RestTemplate to return a valid person (user exists in People service)
        when(restTemplate.getForEntity(anyString(), eq(Person.class)))
                .thenReturn(new ResponseEntity<>(validPerson, HttpStatus.OK));

        // Mock service to return the created account user
        when(accountUserService.upsertAccountUser(any(AccountUser.class))).thenReturn(createdAccountUser);

        // Act & Assert
        mockMvc.perform(post("/accountuser/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(newAccountUser)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.accountId").value(1))
                .andExpect(jsonPath("$.username").value("validuser"));
    }

    @Test
    void testCreateAccountUserMappingWithInvalidUser() throws Exception {
        // Arrange
        AccountUser newAccountUser = new AccountUser();
        newAccountUser.setAccountId(1);
        newAccountUser.setUsername("invaliduser");

        // Mock RestTemplate to throw 404 (user not found in People service)
        HttpClientErrorException notFoundException = new HttpClientErrorException(
                HttpStatus.NOT_FOUND, "User not found");
        when(restTemplate.getForEntity(anyString(), eq(Person.class)))
                .thenThrow(notFoundException);

        // Act & Assert
        mockMvc.perform(post("/accountuser/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(newAccountUser)))
                .andExpect(status().isNotFound());
    }

    @Test
    void testUpdateAccountUserMapping() throws Exception {
        // Arrange
        AccountUser updatedAccountUser = new AccountUser();
        updatedAccountUser.setAccountId(1);
        updatedAccountUser.setUsername("updateduser");

        when(accountUserService.upsertAccountUser(any(AccountUser.class))).thenReturn(updatedAccountUser);

        // Act & Assert
        mockMvc.perform(put("/accountuser/")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(updatedAccountUser)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.accountId").value(1))
                .andExpect(jsonPath("$.username").value("updateduser"));
    }
}

