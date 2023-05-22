import { Box, Button, Modal } from "@mui/material"
import { FormEvent, useState } from "react";
import { RJSFSchema, } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import Form, { IChangeEvent } from '@rjsf/core';
import { style } from "../style";

export const CreateAccount = () => {
	const accountId = Math.floor(Math.random() * 10000)
	const schema: RJSFSchema = {
		title: 'Create Account',
		type: 'object',
		required: ['displayName'],
		properties: {
			displayName: { type: 'string', title: 'Display Name' },
		},
	};
	const uiSchema = {
		"type": "VerticalLayout",
		"elements": [
			{
				"type": "Control",
				"scope": "#/properties/''",
				"options": {
					"ui:widget": "button",
					"autocomplete": true
				}
			}
		],
	}

	const log = (type:string) => console.log.bind(console, type);
	const [open, setOpen] = useState<boolean>(false);
  const handleClose = () => setOpen(false);
	const handleOpen = () => setOpen(true);
	const onSubmit = async (data: IChangeEvent<any>, _event: FormEvent<any>) => {
		const accountDetails = data.formData;
		try {
			await fetch('http://127.0.0.1:18088/account/', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					id: accountId,
					displayName: accountDetails.displayName
				}),
			});
			setOpen(false);
			console.log('success');
		} catch (error) {
			return error
		}
	}

	return (
		<div className="button-modal-container">
			<Button onClick={handleOpen} variant="contained">Create Account</Button>
				<Modal
					open={open}
					onClose={handleClose}
					aria-labelledby="modal-modal-title"
					aria-describedby="modal-modal-description"
				>
				<Box sx={style}>
					<Form
						schema={schema}
						uiSchema={uiSchema}
						validator={validator}
						onSubmit={onSubmit}
						onError={log('errors')}
					>
					</Form>
				</Box>
				</Modal>
		</div>
	)
}