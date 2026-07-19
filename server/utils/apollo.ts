import type { ApolloServer } from '@apollo/server'
import type { GraphQLContext } from '~/domain/shared/graphql/builder'

let instance: ApolloServer<GraphQLContext> | undefined

export const setApollo = (apollo: ApolloServer<GraphQLContext>) => {
  instance = apollo
}

export const useApollo = () => {
  if (!instance) throw new Error('Apollo Server not initialized — plugin not loaded yet')
  return instance
}
