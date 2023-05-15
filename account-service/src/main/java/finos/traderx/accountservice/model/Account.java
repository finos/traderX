package finos.traderx.accountservice.model;

import java.io.Serializable;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "ACCOUNTS")
public class Account implements Serializable {

		private static final long serialVersionUID = 1L;

		@Id
		@Column(name = "ID")
		@GeneratedValue(strategy = GenerationType.SEQUENCE)
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
