
import useBaseUrl from '@docusaurus/useBaseUrl'
import React from 'react'
import styles from './HomepageFeatures.module.css'
import Link from '@docusaurus/Link'

type FeatureItem = {
	title: string | JSX.Element
	description: JSX.Element
	column?: 3 | 4 | 6 | 12
	image?: string
	brTop?: boolean
	brBottom?: boolean
}

const FeatureList: FeatureItem[] = [
	{
		title: 'What is it?',
		description: (
			<>
				TraderX is a Sample Trading Application, designed to be a distributed reference application 
                in the financial services domain which can serve as a starting point for experimentation 
                with various techniques and other open source projects.  It is designed to be simple
                and accessible to developers of all backgrounds, with minimal pre-assumptions, and it 
                can serve as a starting point for educational and experimentation purposes.

                It is designed to be runnable from any developer workstation with minimal assumptions
                other than Node, Java and Python runtimes. The libraries and toolkits it uses are meant
                to be as vanilla as possible, to preserve its approachability by developers of all levels.
			</>
		),
	},
	{
		title: 'Why is it important?',
		column: 6,
		description: (
			<>
				TraderX provides a simple, accessible financial-services relevant reference application which may
                resemble what some organizations have in production today. It can serve as a starting point for introducing
                new technologies and techniques, illustrating ideas and integrations, and powering hackathons.  It's purposefully
                simple to allow for easy experimentation and learning without requiring a deep understanding of the financial
                services domain. It can accelerate ideation and prototyping and provide the audience with a familiar context
                when demonstrating new technologies and techniques.
			</>
		),
	},
	{
		title: 'How does it work?',
		column: 6,
		description: (
			<>
				Learn more about the project - including a brief demo, in the Keynote Demo session 
that was presented at the <a href="https://events.linuxfoundation.org/archive/2023/open-source-finance-forum-new-york/)">Open Source in Finance Forum 2023</a> <br clear="all" />
 <a href="https://youtu.be/tSKDJlRYkm0?list=PLmPXh6nBuhJueQS5q-5IU3-0vmZEIUbz0&t=400"><img src="/img/graphics/2023_osff_video_thumb.png" /> </a>
			</>
		),
	},
	{
		title: 'What are the core components?',
		brTop: true,
		brBottom: true,
		description: (
			<div className='container'>
				<section className='row text--center'>
					{[
						{
							title: 'Database',
							description: (
								<>
									Self-contained simple SQL database for storing accounts, trades and positions. In this reference 
                                    implementation for simplicity, this is implemented using H2 database with a TCP server for access 
                                    from other components in the system.
								</>
							),
						},
						{
							title: 'Account Service',
							description: (
								<>
									Java/Spring Boot REST service for managing accounts and returning a list of available accounts. This is also 
                                    used as a form of account validation when handling incoming trade requests.
								</>
							),
						},
						{
							title: 'Position Service',
							description: (
								<>
									Java/Spring Boot REST service for returning a list of trades and positions (from the database) for a given
                                    account to hydrate the blotters when the UI is initially loaded.
								</>
							),
						},
						{
							title: 'Reference Data Service',
							description: (
								<>
									JavaScript/NestJS REST service for returning a list of valid securities - for populating the UI dropdown
                                    for trading, as well as used during validation of incoming trade requests.  This is currently consuming
                                    from a flat file, but in a production implementation, this would be replaced with a more robust data source.
								</>
							),
						},
                        {
							title: 'Trade Service',
							description: (
								<>
									Java/SpringBoot REST service for accepting new trades. This will perform validation using Account and 
                                    Reference Data services, and if the trade is valid, it will be published on the trade feed for processing.
								</>
							),
						},
                        {
							title: 'Trade Feed',
							description: (
								<>
									Self-contained SocketIO/NodeJS message bus with a viewer that allows you to see the messages being published
                                    and consumed in real-time. Trade processing happens over
                                    this message bus (from the trade service and trade processor), and the front-end blotter is updated in real-time
                                    via subscription to the account-relevant feed for positions and trades.
								</>
							),
						},
                        {
							title: 'Trade Processor',
							description: (
								<>
									Java/Spring Boot REST service which also consumes messages from the trade feed.  It will process the incoming
                                    orders/trades, persist in the database and publish updated positions and trade messages back to the trade feed.
                                    This is meant to mimic the behavior of trading engines, connecting only to the database and message feeds.
								</>
							),
						},
                        {
							title: 'People Service',
							description: (
								<>
									.NET Core REST service for returning a list of valid users in the system. This is currently consuming from a 
                                    flat file, and it is used for populating the UI dropdown on the account management page.  In a production
                                    system this might consume from an LDAP or other user directory/identity management source.
								</>
							),
						},
                        {
							title: 'Web Front-End',
							description: (
								<>
									Angular-based GUI for executing trades, viewing trades and positions, and managing accounts. This connects
                                    to all of the REST services mentioned above except for the trade-processor which runs 'headless' and interacts
                                    only with the database and message bus. 
								</>
							),
						},
                        {
							title: 'Ingress Controller',
							description: (
								<>
									Nginx-based ingress controller for routing traffic to the various services when run in a containerized environment.
                                    There is also a similar proxy inside the web-front-end which does this in a lightweight way for local development.
								</>
							),
						},
					].map(({ title, description }) => (
						<div className='text--left col col--6'>
							<h3>{title}</h3>
							<p>{description}</p>
						</div>
					))}
				</section>
			</div>
		),
	}
]

function Feature({ title, description, ...props }: FeatureItem) {
	let border = {}
	if (props?.brTop) border = { borderTop: '1px solid var(--ifm-color-primary-darkest)', paddingTop: '1em' }
	if (props?.brBottom)
		border = { ...border, borderBottom: '1px solid var(--ifm-color-primary-darkest)', marginBottom: '1em' }
	return (
		<div className={`col col--${props?.column ? props.column : 12}`}>
			<div className='text--center padding--lg' style={{ ...border }}>
				{props?.image && (
					<img
						className={styles.featureSvg}
						alt={typeof title === 'string' ? title : title.props.children}
						src={useBaseUrl(props.image)}
					/>
				)}
				<div className='padding-horiz--md'>
					<h2>{title}</h2>
					<p>{description}</p>
				</div>
			</div>
		</div>
	)
}

export default function HomepageFeatures(): JSX.Element {
	return (
		<section className={styles.features}>
			<div className='container'>
				<div className='row'>
					{FeatureList.map((props, idx) => (
						<Feature key={idx} {...props} />
					))}
				</div>
			</div>
		</section>
	)
}
