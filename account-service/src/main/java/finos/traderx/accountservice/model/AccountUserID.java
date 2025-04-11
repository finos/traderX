package finos.traderx.accountservice.model;

import java.io.Serializable;

public class AccountUserID implements Serializable {
	private Integer accountId;
	private String username;

	public AccountUserID() {
		// Entity
	}

	public Integer getAccountId() {
		return accountId;
	}

	public void setAccountId(Integer accountId) {
		this.accountId = accountId;
	}

	public String getUsername() {
		return username;
	}

	public void setUsername(String username) {
		this.username = username;
	}
}
