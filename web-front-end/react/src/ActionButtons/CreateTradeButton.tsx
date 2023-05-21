import { Box, Button,  Modal, ToggleButton, ToggleButtonGroup } from "@mui/material"
import { MouseEvent, useCallback, useRef, useState } from "react";
import { RJSFSchema, } from '@rjsf/utils';
import validator from '@rjsf/validator-ajv8';
import Form, { IChangeEvent } from '@rjsf/core';
import { style } from "../style";
import { ActionButtonsProps, RefData, RefDataCompanyNames, Side } from "./types";

export const CreateTradeButton = ({accountId}:ActionButtonsProps) => {
	const [refData, setRefData] = useState<any>([]);
	const tradeId = Math.floor(Math.random() * 1000000)
	const schema: RJSFSchema = {
		title: 'Create Trade',
		type: 'object',
		required: ['security', 'quantity'],
		properties: {
			security: { type: 'string', title: 'Security', enum: refData },
			quantity: { type: 'integer', title: 'Quantity'},
			// side: { type: 'string', title: 'Side', enum: ['Buy', 'Sell'] },
		},
	};
	const uiSchema = {
		"ui:submitButtonOptions": {
			"submitText": "Confirm Details",
			"norender": false,
			"props": {
				"disabled": false,
				"className": "btn btn-info"
			}
		}
	}
	const log = (type:string) => console.log.bind(console, type);
	const handleSubmit = async () => {
		const tradeDetails = formDataRef.current;
		const response = await fetch('http://127.0.0.1:18092/trade/', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				id: `TRADE-${tradeId}`,
				security: tradeDetails.security,
				quantity: tradeDetails.quantity,
				accountId: accountId,
				side: sideRef.current,
			}),
		});
		if (response.ok) {
			setOpen(false);
			console.log('success');
		} else {
			console.log('error');
		}
	}
	const [open, setOpen] = useState<boolean>(false);
  const handleClose = () => setOpen(false);
	const handleOpen = async () => {
		setOpen(true);
		try {
			const response = await fetch("http://127.0.0.1:18085/stocks");
			const data = await response.json();
			setRefData([])
			data.forEach((refData:RefData) => {
				return (
					setRefData((
						prevData:RefDataCompanyNames[]
						) => [...prevData, refData.companyName]))
			})
		} catch (error) {
			return error
		}
	}

	const [side, setSide] = useState<Side>();
	const sideRef = useRef<Side>();
	const formDataRef = useRef<any>([]);

  const handleToggleChange = useCallback((
    _event: MouseEvent<HTMLElement>,
		newSide: Side,
  ) => {
		sideRef.current = newSide;
    // setSide(newSide);
  }, []);

	const handleFormChange = useCallback((
		data: IChangeEvent<any, RJSFSchema, any>
	) => {
		formDataRef.current = data.formData
		console.log(formDataRef.current, sideRef.current);
	}, [])

	return (
		<div className="modal-container">
			<Button onClick={handleOpen} variant="contained">Create New Trade</Button>
				<Modal
					open={open}
					onClose={handleClose}
					aria-labelledby="modal-modal-title"
					aria-describedby="modal-modal-description"
				>
				<Box className="modal-components" sx={style}>
					<Form
						schema={schema}
						uiSchema={uiSchema}
						validator={validator}
						onChange={handleFormChange}
						// onSubmit={onSubmit}
						onError={log('errors')}
					>
						<ToggleButtonGroup
							color="primary"
							size="small"
							// value={sideRef.current}
							exclusive
							onChange={handleToggleChange}
							aria-label="tradeSide"
						>
							<ToggleButton value="Buy">Buy</ToggleButton>
							<ToggleButton value="Sell">Sell</ToggleButton>
						</ToggleButtonGroup>
						<div style={{float: 'right'}} className="submit-button-container">
							<Button variant="contained" color="success" onClick={handleSubmit}>Submit</Button>
						</div>
					</Form>
				</Box>
				</Modal>
		</div>
	)
}