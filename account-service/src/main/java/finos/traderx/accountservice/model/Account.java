package finos.traderx.accountservice.model;

import java.io.Serializable;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.SequenceGenerator;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "ACCOUNTS")
public class Account implements Serializable {

		private static final long serialVersionUID = 1L;

		@Id
		@Column(name = "ID")
		@GeneratedValue(strategy = GenerationType.SEQUENCE, generator="account_generator")
		@SequenceGenerator(name = "account_generator", sequenceName = "ACCOUNTS_SEQ", allocationSize = 1)

		private int id;

		@Column(length = 50, name = "DisplayName")
		private String displayName;

		public int getId() {
			return this.id;
		}

		public void setId(int id) {
			this.id = id;
		}

		public String getDisplayName() {
			return this.displayName;
		}

		public void setDisplayName(String displayName) {
			this.displayName = displayName;
		}
}
